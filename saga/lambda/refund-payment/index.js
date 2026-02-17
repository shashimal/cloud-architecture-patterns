/**
 * refund_payment: Compensation for ChargePayment.
 */
exports.handler = async (event) => {
    console.log("Compensating: Refunding Transaction", event.transactionId);

    // Logic to call Payment Gateway Refund API
    return { ...event, paymentStatus: "REFUNDED" };
};