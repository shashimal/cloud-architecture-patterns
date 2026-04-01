exports.handler = async (event) => {
    const amount =
        event.amount ||
        (event.createOrderResult && event.createOrderResult.amount);

    // Demo: fail large payments to trigger compensation
    if (amount > 1000) {
        throw new Error("Payment declined: amount too large");
    }

    return {
        charged: true,
        transactionId: "tx-" + Date.now(),
        amount
    };
};