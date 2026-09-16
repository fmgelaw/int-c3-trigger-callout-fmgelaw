/**
 * Service class to interact with the NewsAPI for fetching top headlines
 */
public with sharing class NewsAPIService {
    // TODO: Define API endpoint constants
    private static final String API_NAMED_CREDENTIAL = 'callout:NewsAPI'; //https://newsapi.org
    private static final String API_ENDPOINT = '/v2/top-headlines';

    // TODO: Define default parameters
    public static final Integer PAGE_SIZE = 20;
    private static final Integer CALLOUT_TIMEOUT_MS = 20000;
    private static final Set<String> VALID_CATEGORIES = new Set<String>{
        'business', 'entertainment', 'general', 'health', 'science', 'sports', 'technology'
    };

    private static final String LOG_TAG = 'NewsAPIService';

    /**
     * Fetches top headlines for a specified category with pagination support
     * @param category The news category (business, entertainment, general, health, science, sports, technology)
     * @param page Page number for pagination
     * @return NewsAPIResponse The wrapper object containing the API response
     */
    public static NewsAPIResponse getTopHeadlinesByCategory(String category, Integer page) {
        return getTopHeadlinesByCategory(category, page, null);
    }

    /**
     * Fetches top headlines for a specified category and country with pagination support
     * @param category The news category (business, entertainment, general, health, science, sports, technology)
     * @param page Page number for pagination
     * @param country Optional 2-letter ISO 3166-1 country code (e.g. 'us'); null omits the parameter
     * @return NewsAPIResponse The wrapper object containing the API response
     */
    public static NewsAPIResponse getTopHeadlinesByCategory(String category, Integer page, String country) {
        // TODO: Implement method to fetch headlines by category
        // - Validate parameters
        // - Build the request URL with fixed page size
        // - Make the callout
        // - Parse and return the response

        try {
            Nebula.Logger.info(
                'getTopHeadlinesByCategory called for category=' + category + ' page=' + page + ' country=' + country
            ).addTag(LOG_TAG);

            // Validate parameters
            if (String.isBlank(category) || !VALID_CATEGORIES.contains(category.toLowerCase())) {
                Nebula.Logger.warn('Invalid category: ' + category).addTag(LOG_TAG);
                throw new NewsAPIException('Invalid category: ' + category);
            }
            if (page == null || page < 1) {
                Nebula.Logger.warn('Invalid page: ' + page).addTag(LOG_TAG);
                throw new NewsAPIException('Page must be a positive integer.');
            }

            // Build the request URL with fixed page size
            String endpoint = API_NAMED_CREDENTIAL + API_ENDPOINT
                + '?category=' + EncodingUtil.urlEncode(category, 'UTF-8')
                + '&page=' + page
                + '&pageSize=' + PAGE_SIZE;
            if (String.isNotBlank(country)) {
                endpoint += '&country=' + EncodingUtil.urlEncode(country, 'UTF-8');
            }

            // Make the callout
            HttpResponse response = makeCallout(endpoint);
            if (response.getStatusCode() != 200) {
                Nebula.Logger.error(
                    'NewsAPI request failed for category ' + category + ' page ' + page
                        + ' with status ' + response.getStatusCode() + '. Response: ' + response.getBody()
                ).addTag(LOG_TAG);
                throw new NewsAPIException(
                    'NewsAPI request failed with status ' + response.getStatusCode() + ': ' + response.getStatus()
                        + '. Response: ' + truncate(response.getBody(), 500)
                );
            }

            // Parse and return the response
            NewsAPIResponse parsedResponse = parseResponse(response.getBody());
            Nebula.Logger.info(
                'getTopHeadlinesByCategory succeeded for category=' + category + ' page=' + page
                    + ' - ' + (parsedResponse.articles != null ? parsedResponse.articles.size() : 0) + ' article(s)'
            ).addTag(LOG_TAG);
            return parsedResponse;
        } finally {
            Nebula.Logger.saveLog();
        }
    }

    /**
     * Helper method to make the HTTP callout
     * @param endpoint The full URL with parameters
     * @return HttpResponse The HTTP response
     */
    private static HttpResponse makeCallout(String endpoint) {
        // TODO: Implement HTTP callout
        // - Create and configure HTTP request
        // - Make the callout
        // - Handle exceptions

        // Create and configure HTTP request
        HttpRequest request = new HttpRequest();
        request.setEndpoint(endpoint);
        request.setMethod('GET');
        request.setTimeout(CALLOUT_TIMEOUT_MS);

        // Make the callout, handling exceptions
        try {
            Http http = new Http();
            return http.send(request);
        } catch (CalloutException ce) {
            Nebula.Logger.error('Callout to NewsAPI failed for endpoint ' + endpoint, ce).addTag(LOG_TAG);
            throw new NewsAPIException('Callout to NewsAPI failed: ' + ce.getMessage(), ce);
        }
    }

    /**
     * Helper method to parse the JSON response
     * @param jsonResponse The JSON response string
     * @return NewsAPIResponse The parsed response object
     */
    private static NewsAPIResponse parseResponse(String jsonResponse) {
        // TODO: Implement JSON parsing
        // - Deserialize JSON to NewsAPIResponse
        // - Handle exceptions

        // Deserialize JSON to NewsAPIResponse, handling exceptions
        try {
            return (NewsAPIResponse) JSON.deserialize(jsonResponse, NewsAPIResponse.class);
        } catch (Exception e) {
            Nebula.Logger.error('Failed to parse NewsAPI response. Body: ' + jsonResponse, e).addTag(LOG_TAG);
            throw new NewsAPIException('Failed to parse NewsAPI response: ' + e.getMessage(), e);
        }
    }

    /**
     * Truncates a string for inclusion in an exception message, so a large response
     * body doesn't blow up the message.
     */
    private static String truncate(String value, Integer maxLength) {
        if (String.isBlank(value)) {
            return value;
        }
        return value.length() > maxLength ? value.substring(0, maxLength) + '...' : value;
    }

    /**
     * Custom exception class for NewsAPI errors
     */
    public class NewsAPIException extends Exception {}
}
