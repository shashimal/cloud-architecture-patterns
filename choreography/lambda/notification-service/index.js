// Notification Service
// Reacts to ALL order lifecycle events from EventBridge.
// In production, this would send emails via SES or SMS via SNS/Pinpoint.
// Here it logs the notification message to CloudWatch Logs.

const NOTIFICATION_TEMPLATES = {
  "order.placed": ({ orderId, customerId, totalAmount }) =>
    `Hi ${customerId}! Your order #${orderId} ($${totalAmount}) has been placed. ` +
    `We are checking availability of your items.`,

  "inventory.reserved": ({ orderId }) =>
    `Great news! All items for order #${orderId} are available and reserved. ` +
    `We are now processing your payment.`,

  "inventory.failed": ({ orderId, reservation }) =>
    `Sorry! Order #${orderId} could not be fulfilled. ` +
    `Reason: ${reservation?.failureReason || "Items out of stock"}. ` +
    `Please try again or contact support.`,

  "payment.processed": ({ orderId, payment }) =>
    `Payment of $${payment?.amount} for order #${orderId} was successful. ` +
    `We are now preparing your shipment!`,

  "payment.failed": ({ orderId, payment }) =>
    `Payment for order #${orderId} failed. ` +
    `Reason: ${payment?.failureReason || "Unknown error"}. ` +
    `Please update your payment method and try again.`,

  "order.fulfilled": ({ orderId, shipment }) =>
    `Your order #${orderId} has been shipped! ` +
    `Tracking number: ${shipment?.trackingNumber} (${shipment?.carrier}). ` +
    `Estimated delivery: ${new Date(shipment?.estimatedDelivery).toDateString()}.`,
};

exports.handler = async (event) => {
  console.log("[NOTIFICATION-SERVICE] Received event:", JSON.stringify(event));

  const detailType = event["detail-type"];
  const detail = event.detail || {};
  const { orderId, customerId } = detail;

  const template = NOTIFICATION_TEMPLATES[detailType];

  if (!template) {
    console.warn(`[NOTIFICATION-SERVICE] No template for event type: ${detailType}`);
    return;
  }

  const message = template(detail);

  // Simulate sending notification (replace with SES/SNS in production)
  console.log(`[NOTIFICATION-SERVICE] [${detailType}] → Customer ${customerId}: ${message}`);

  // Structured log for easy querying in CloudWatch Insights
  console.log(
    JSON.stringify({
      type: "NOTIFICATION_SENT",
      eventType: detailType,
      orderId,
      customerId,
      message,
      timestamp: new Date().toISOString(),
    })
  );
};
