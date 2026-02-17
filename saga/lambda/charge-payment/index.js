
/**
 * charge_payment: Simulates charging a customer.
 */
exports.handler = async (event) => {
    console.log("Charging Payment for Order:", event.orderId);

    if (event.failAt === 'charge_payment') throw new Error("Payment Authorization Failed");

    // In a real app, you'd call Stripe/Square API here
    return { ...event, paymentStatus: "CHARGED", transactionId: `TX_${Math.random().toString(36).substr(2, 9)}` };
};

