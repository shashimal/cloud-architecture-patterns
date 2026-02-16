/**
 * Worker Lambda Function
 * Processes individual tasks in parallel during the scatter phase
 */

exports.handler = async (event) => {
    console.log('Worker received event:', JSON.stringify(event, null, 2));

    try {
        const { item } = event;

        // Simulate processing work
        // Replace this with your actual business logic
        await processTask(item);

        const result = {
            item: item,
            processed: true,
            result: `Processed: ${item}`,
            timestamp: new Date().toISOString(),
            processingTime: Math.random() * 1000 // Simulated processing time
        };

        console.log('Worker completed:', result);
        return result;

    } catch (error) {
        console.error('Worker error:', error);
        throw error;
    }
};

/**
 * Simulates task processing
 * Replace with your actual business logic
 */
async function processTask(item) {
    // Simulate async work
    await new Promise(resolve => setTimeout(resolve, Math.random() * 2000));

    // Example: Transform data, call external API, process records, etc.
    console.log(`Processing item: ${item}`);

    return true;
}
