exports.handler = async (event) => {
    const txId =
      (event.chargePaymentResult &&
        event.chargePaymentResult.transactionId) ||
      "unknown";
  
    // In a real system, call your payment provider here
    return {
      refunded: true,
      transactionId: txId
    };
  };