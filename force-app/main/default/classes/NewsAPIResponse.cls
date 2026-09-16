/**
 * Wrapper class for parsing the NewsAPI response
 */
public class NewsAPIResponse {
    // TODO: Define fields to match the NewsAPI response structure
    public String status { get; set; }
    public Integer totalResults { get; set; }
    public List<Article> articles { get; set; }
    
    /**
     * Inner class representing a news article
     */
    public class Article {
        // TODO: Define article fields
        // Example fields:
        // public String title { get; set; }
        // public String description { get; set; }
        // public String url { get; set; }
        // etc.
        public Source source { get; set; }
        public String author { get; set; }
        public String title { get; set; }
        public String description { get; set; }
        public String url { get; set; }
        public String urlToImage { get; set; }
        public String publishedAt { get; set; }
        public String content { get; set; }
    }

    /**
     * Inner class representing a news source
     */
    public class Source {
        // TODO: Define source fields
        // Example fields:
        // public String id { get; set; }
        // public String name { get; set; }
        public String id { get; set; }
        public String name { get; set; }
    }

    /**
     * Static method to convert an API article to a Salesforce Article__c record
     * @param apiArticle The API article to convert
     * @return Article__c The Salesforce record
     */
    public static Article__c convertToSObject(Article apiArticle) {
        // TODO: Implement conversion from API article to Salesforce record
        // Consider:
        // - Generating a unique record name
        // - Setting article fields from the API response
        // - Handling content length limits if needed
        // - Handling date conversion
        if (apiArticle == null) {
            return null;
        }

        Article__c articleRecord = new Article__c();
        // Name is the standard Text name field (80-char limit), Title__c keeps the full-length (255) title
        articleRecord.Name = truncate(apiArticle.title, 80);
        articleRecord.Title__c = truncate(apiArticle.title, 255);
        articleRecord.Author__c = truncate(apiArticle.author, 255);
        articleRecord.Description__c = apiArticle.description;
        articleRecord.Content__c = apiArticle.content;
        articleRecord.url__c = truncate(apiArticle.url, 255);
        articleRecord.urlToImage__c = truncate(apiArticle.urlToImage, 255);
        articleRecord.Source__c = truncate(apiArticle.source != null ? apiArticle.source.name : null, 255);
        articleRecord.Published_At__c = parsePublishedAt(apiArticle.publishedAt);
        // Category__c, Country__c, and News_Category__c are query context, not part of the
        // article payload itself - the caller sets those after this conversion.

        return articleRecord;
    }

    /**
     * Truncates a string to fit within a field's max length, since NewsAPI does not
     * guarantee title/author/url values stay within Salesforce's 255-char Text limit.
     */
    private static String truncate(String value, Integer maxLength) {
        if (String.isBlank(value)) {
            return value;
        }
        return value.length() > maxLength ? value.substring(0, maxLength) : value;
    }

    /**
     * Parses NewsAPI's UTC timestamp (e.g. "2026-09-11T13:32:20Z") into a Datetime.
     * Returns null on a missing or unexpected format rather than failing the whole conversion.
     */
    private static Datetime parsePublishedAt(String publishedAt) {
        if (String.isBlank(publishedAt)) {
            return null;
        }
        try {
            // String "2026-09-11T13:32:20Z" (explicitly UTC per the Z)
            // Reshaped to "2026-09-11 13:32:20" (just changing separators, not the values)
            // so Datetime.valueOfGmt can parse it as the same UTC instant.
            String gmtValue = publishedAt.replace('T', ' ').replace('Z', '');
            return Datetime.valueOfGmt(gmtValue);
        } catch (Exception e) {
            return null;
        }
    }
} 