/**
 * AWS Lambda Function for Chat Completion
 * Supports Anthropic, OpenAI, Gemini, and Perplexity providers
 * Uses @rocketnew/llm-sdk for multi-provider support
 */

const { completion } = require('@rocketnew/llm-sdk');

function sendSSE(stream, data) {
  const message = `data: ${JSON.stringify(data)}\n\n`;
  stream.write(message);
}

function formatErrorResponse(error, provider) {
  const statusCode = error.statusCode || 500;
  const providerName = error.llmProvider || provider || 'Unknown';
  
  return {
    error: `${providerName.toUpperCase()} API error: ${statusCode}`,
    details: error.message || error.body || String(error),
  };
}

function sendError(stream, errorResponse) {
  sendSSE(stream, {
    type: 'error',
    error: errorResponse.error,
    details: errorResponse.details,
  });
}

const handlerLogic = async (event, responseStream, context) => {
  const awslambda = globalThis.awslambda || global.awslambda;

  if (!awslambda || !awslambda.HttpResponseStream) {
    throw new Error('Streaming not supported in this environment');
  }

  // Determine stream mode for response headers
  let stream = false;
  try {
    const parsed = event.body ? JSON.parse(event.body) : {};
    stream = parsed.stream === true || parsed.stream === 'true';
  } catch (e) {
  }

  // Set response metadata (headers) based on stream mode
  const metadata = {
    statusCode: 200,
    headers: stream ? {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    } : {
      'Content-Type': 'application/json',
    },
  };

  // Only allow POST requests
  if (event.requestContext?.http?.method !== 'POST' && event.httpMethod !== 'POST') {
    metadata.statusCode = 405;
    responseStream = awslambda.HttpResponseStream.from(responseStream, metadata);
    const errorResponse = {
      error: 'Method not allowed: Use POST',
      details: 'This endpoint only accepts POST requests',
    };
    if (stream) {
      sendError(responseStream, errorResponse);
    } else {
      responseStream.write(JSON.stringify(errorResponse));
    }
    responseStream.end();
    return;
  }

  // Wrap the response stream with metadata
  responseStream = awslambda.HttpResponseStream.from(responseStream, metadata);

  let body = {};
  try {
    body = event.body ? JSON.parse(event.body) : {};
  } catch (e) {
    const errorResponse = {
      error: 'Invalid request: JSON parsing failed',
      details: 'The request body must be valid JSON',
    };
    if (stream) {
      sendError(responseStream, errorResponse);
    } else {
      responseStream.write(JSON.stringify(errorResponse));
    }
    responseStream.end();
    return;
  }

  try {
    const { messages, model, provider } = body;

    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      const errorResponse = {
        error: 'Invalid request: Messages array is required',
        details: 'The request must include a non-empty messages array',
      };
      if (stream) {
        sendError(responseStream, errorResponse);
      } else {
        responseStream.write(JSON.stringify(errorResponse));
      }
      responseStream.end();
      return;
    }

    let apiKey;

    if (provider === 'OPEN_AI') {
      apiKey = process.env.OPENAI_API_KEY;
    } else if (provider === 'GEMINI') {
      apiKey = process.env.GEMINI_API_KEY;
    } else if (provider === 'ANTHROPIC') {
      apiKey = process.env.ANTHROPIC_API_KEY;
    } else if (provider === 'PERPLEXITY') {
      apiKey = process.env.PERPLEXITY_API_KEY;
    }

    if (!apiKey) {
      const errorResponse = {
        error: `${provider ? provider.toUpperCase() : 'LLM Provider'} API key is not configured`,
        details: 'The API key for this provider is missing in environment variables',
      };
      if (stream) {
        sendError(responseStream, errorResponse);
      } else {
        responseStream.write(JSON.stringify(errorResponse));
      }
      responseStream.end();
      return;
    }

    // Handle streaming mode
    if (stream) {
      // Send initial metadata
      sendSSE(responseStream, {
        type: 'start',
        model,
        timestamp: new Date().toISOString(),
      });

      try {
        const chatCompletion = await completion({
          model,
          messages,
          api_key: apiKey,
          stream: true,
          ...(body.parameters || {}),
        });

        // Stream chunks as they arrive
        for await (const chunk of chatCompletion) {
          sendSSE(responseStream, {
            type: 'chunk',
            chunk,
          });
        }

        // Send completion signal
        sendSSE(responseStream, {
          type: 'done',
          timestamp: new Date().toISOString(),
        });
      } catch (streamError) {
        const errorResponse = formatErrorResponse(streamError, provider);
        sendError(responseStream, errorResponse);
      }
    } else {
      // Handle non-streaming mode
      try {
        const chatCompletion = await completion({
          model,
          messages,
          api_key: apiKey,
          stream: false,
          ...(body.parameters || {}),
        });

        // Send the complete response as JSON
        responseStream.write(JSON.stringify(chatCompletion));
      } catch (error) {
        const errorResponse = formatErrorResponse(error, provider);
        responseStream.write(JSON.stringify(errorResponse));
      }
    }
  } catch (error) {
    const errorResponse = formatErrorResponse(error, provider);
    if (stream) {
      sendError(responseStream, errorResponse);
    } else {
      responseStream.write(JSON.stringify(errorResponse));
    }
  } finally {
    responseStream.end();
  }
};

const awslambdaGlobal = globalThis.awslambda || global.awslambda;

if (awslambdaGlobal && awslambdaGlobal.streamifyResponse) {
  exports.handler = awslambdaGlobal.streamifyResponse(handlerLogic);
} else {
  exports.handler = handlerLogic;
}
