/**
 * Aggregator Lambda Function
 * Collects and combines results from all worker functions (gather phase)
 */

exports.handler = async (event) => {
    console.log('Aggregator received event:', JSON.stringify(event, null, 2));

    try {
        const results = event.results || [];

        // Aggregate results
        const aggregated = {
            totalItems: results.length,
            successCount: results.filter(r => r.processed).length,
            failureCount: results.filter(r => !r.processed).length,
            results: results,
            summary: generateSummary(results),
            completedAt: new Date().toISOString()
        };

        console.log('Aggregation complete:', aggregated);
        return aggregated;

    } catch (error) {
        console.error('Aggregator error:', error);
        throw error;
    }
};

/**
 * Generates summary statistics from worker results
 */
function generateSummary(results) {
    const processingTimes = results.map(r => r.processingTime || 0);

    return {
        averageProcessingTime: processingTimes.reduce((a, b) => a + b, 0) / processingTimes.length,
        maxProcessingTime: Math.max(...processingTimes),
        minProcessingTime: Math.min(...processingTimes),
        items: results.map(r => r.item)
    };
}
