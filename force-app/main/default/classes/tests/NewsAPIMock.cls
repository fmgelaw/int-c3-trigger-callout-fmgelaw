/**
 * Mock class for testing NewsAPI callouts
 * @author Integration Developer Assignment
 */
public class NewsAPIMock implements HttpCalloutMock {
    private Integer statusCode;
    private String body;
    private Map<String, String> headers;
    
    public NewsAPIMock(Integer statusCode, String body) {
        this.statusCode = statusCode;
        this.body = body;
        this.headers = new Map<String, String>();
    }
    
    public NewsAPIMock(Integer statusCode, String body, Map<String, String> headers) {
        this.statusCode = statusCode;
        this.body = body;
        this.headers = headers;
    }
    
    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(statusCode);
        res.setBody(body);
        
        // Set headers if provided
        for (String key : headers.keySet()) {
            res.setHeader(key, headers.get(key));
        }
        
        return res;
    }
    
    /**
     * Creates a successful mock response with sample news data
     * @return NewsAPIMock A mock with successful response
     */
    public static NewsAPIMock createSuccessMock() {
        String successBody = '{' +
            '"status": "ok",' +
            '"totalResults": 2,' +
            '"articles": [' +
                '{' +
                    '"source": {"id": "test-1", "name": "Test Source 1"},' +
                    '"title": "Test Article 1",' +
                    '"description": "Test Description 1",' +
                    '"url": "https://test1.com",' +
                    '"urlToImage": "https://test1.com/image.jpg",' +
                    '"publishedAt": "2024-03-28T12:00:00Z"' +
                '},' +
                '{' +
                    '"source": {"id": "test-2", "name": "Test Source 2"},' +
                    '"title": "Test Article 2",' +
                    '"description": "Test Description 2",' +
                    '"url": "https://test2.com",' +
                    '"urlToImage": "https://test2.com/image.jpg",' +
                    '"publishedAt": "2024-03-28T13:00:00Z"' +
                '}' +
            ']' +
        '}';
        
        return new NewsAPIMock(200, successBody);
    }
    
    /**
     * Creates an error mock response
     * @return NewsAPIMock A mock with error response
     */
    public static NewsAPIMock createErrorMock() {
        String errorBody = '{' +
            '"status": "error",' +
            '"code": "apiKeyInvalid",' +
            '"message": "Invalid API key"' +
        '}';
        
        return new NewsAPIMock(401, errorBody);
    }
} 