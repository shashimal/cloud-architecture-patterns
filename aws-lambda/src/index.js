exports.handler = async (event) => {
  console.log('Received event:', JSON.stringify(event, null, 2));

  const response = {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: 'Hello from AWS Lambda!',
      timestamp: new Date().toISOString(),
      environment: process.env.ENVIRONMENT || 'unknown',
    }),
  };

  return response;
};
