# Cloud Code Academy - Integration Developer Program
## Lesson: Outbound Callouts from Triggers

This assignment focuses on implementing outbound callouts from Salesforce, using Queueable Apex, and handling pagination from external APIs.

## 🎯 Learning Objectives

By the end of this lesson, you will be able to:
- Implement asynchronous callouts from Salesforce triggers using Queueable Apex
- Build robust API integration services with proper separation of concerns
- Implement pagination for external API callouts
- Handle error scenarios in integrations
- Create wrapper classes to deserialize JSON API responses

## 📋 Assignment Overview

In this assignment, you will be implementing a News Article integration with the NewsAPI.org service. The application will synchronize news articles based on categories defined in Salesforce, using Queueable Apex processing.

Your implementation must:
1. Make callouts when News Category records are created or updated with Sync set to true
2. Use Queueable Apex for all operations, supporting multi-page sync
3. Store the retrieved articles in Article__c custom objects

## 🔨 Prerequisites

1. A NewsAPI.org API key (sign up at https://newsapi.org)
2. An External Credential and a Named Credential named `NewsAPI` in your org (see [Named Credential Setup](#-named-credential-setup))

## ✍️ Assignment Tasks

Your tasks for this assignment include:

1. Implement `NewsAPIResponse` class for deserializing the API response, with a static method to convert API articles to Salesforce records
2. Implement `NewsAPIService` class for making callouts to NewsAPI, using a fixed page size
3. Complete the `NewsCategoryTriggerHandler` class to handle Queueable-based callouts
4. Complete the `NewsCategoryQueueable` class to support paginated callouts with a maximum page limit
5. Make sure the trigger correctly handles both insert and update scenarios

## 🔑 Named Credential Setup

> ⚠️ **The Named Credential must be named exactly `NewsAPI`.** `NewsAPIService.cls` calls out to
> `callout:NewsAPI`, so any other developer name fails at runtime with
> `System.CalloutException: Unable to find the endpoint`. Note that Salesforce auto-generates the
> **Name** from the **Label** — a label of `News API` produces the name `News_API`, which will
> **not** work. Set the Name field manually.

NewsAPI.org authenticates with an `X-Api-Key` header. You'll store that key in an **External
Credential** so it never appears in your Apex, then attach it to a Named Credential.

### Step 1 — Create the External Credential

Setup → **Security > Named Credentials** → **External Credentials** tab → **New**

| Field | Value |
| --- | --- |
| Label | `NewsAPI Auth` |
| Name | `NewsAPI_Auth` |
| Authentication Protocol | **Custom** |

Save, then on the detail page under **Principals**, click **New**:

| Field | Value |
| --- | --- |
| Parameter Name | `News_Admin` |
| Sequence Number | `1` |
| Identity Type | **Named Principal** |

Under **Authentication Parameters** on that principal, add:

| Name | Value |
| --- | --- |
| `ApiKey` | *your NewsAPI.org API key* |

### Step 2 — Create the Named Credential

Setup → **Security > Named Credentials** → **Named Credentials** tab → **New**

> The list view has two buttons: **New** and **New Legacy**. Use **New**.

| Field | Value |
| --- | --- |
| Label | `NewsAPI` |
| Name | `NewsAPI` ← must match `callout:NewsAPI` |
| URL | `https://newsapi.org` |
| External Credential | `NewsAPI Auth` |
| Generate Authorization Header | **unchecked** |
| Allow Formulas in HTTP Header | **checked** |

Save, then on the Named Credential detail page add a **Custom Header**:

| Name | Value |
| --- | --- |
| `X-Api-Key` | `{!$Credential.NewsAPI_Auth.ApiKey}` |

The URL is the base host only — `NewsAPIService` appends the `/v2/top-headlines` path itself.

### Step 3 — Grant access to the External Credential

⚠️ **Skipping this step is the most common cause of a `401` on an otherwise correct setup.**

Setup → **Permission Sets** → create or open a permission set → **External Credential Principal
Access** → **Edit** → add `NewsAPI_Auth - News_Admin` → **Save**. Then assign that permission set
to yourself.

### Step 4 — Verify

Run this in **Developer Console → Debug → Open Execute Anonymous Window**:

```apex
HttpRequest req = new HttpRequest();
req.setEndpoint('callout:NewsAPI/v2/top-headlines?country=us&category=technology&pageSize=1');
req.setMethod('GET');
HttpResponse res = new Http().send(req);
System.debug(res.getStatusCode() + ' => ' + res.getBody());
```

A `200` with a JSON body means you're ready. Common failures:

| Symptom | Cause |
| --- | --- |
| `System.CalloutException: Unable to find the endpoint` | Named Credential name isn't exactly `NewsAPI` |
| `System.CalloutException: Field NewsAPI_Auth.ApiKey does not exist. Check spelling.` | You never added the `ApiKey` **Authentication Parameter** to the `News_Admin` principal in Step 1, or its name doesn't match the one in your `{!$Credential...}` formula |
| `401` `apiKeyMissing` | The header didn't reach NewsAPI — permission set not assigned, or **Allow Formulas in HTTP Header** is unchecked |
| `401` `apiKeyInvalid` | Header arrived but the key is wrong — check the value on the External Credential principal |
| `429` `rateLimited` | Free tier quota exhausted; wait and retry |

## 🧪 Testing Requirements

- Test classes have been provided for you in the `force-app/main/default/classes/tests` folder.
- `NewsCategoryTriggerHandlerTest` tests the trigger handler for insert and update operations.
- `NewsAPIServiceTest` tests the NewsAPIService class for making callouts to NewsAPI.
- Ensure all tests pass with proper coverage

## 📋 Valid News Categories

The following are valid categories for the NewsAPI:
- business
- entertainment
- general
- health
- science
- sports
- technology

## 🎯 Success Criteria

Your implementation should:
- Pass all test methods in the provided test classes
- Properly deserialize JSON responses from NewsAPI
- Create Article__c records from the API response
- Include comprehensive error handling
- Follow Salesforce best practices for integration

## 💡 Tips

- Review the API documentation at [NewsAPI Documentation](https://newsapi.org/docs)
- Use the Developer Console debug logs to troubleshoot
- Test with mock responses before making actual API calls
- Pay attention to error handling for various scenarios

## 📚 Resources

- [Apex Developer Guide: Queueable Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_queueable.htm)
- [Apex Developer Guide: Callouts from Triggers](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_triggers_bestpract.htm)
- [JSON Deserialization in Apex](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_methods_system_json_overview.htm)
- [Named Credentials in Salesforce](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_callouts_named_credentials.htm)

## 🏆 Extra Credit - Optional Challenge

Once you've completed the basic implementation, try these challenges:
1. Add support for additional search parameters
2. Calculate the optimal number of pages to sync based on the API's total results
3. Implement custom logging to track integration activity
4. Add error handling that creates Error__c records with detailed information

## ❓ Support

If you need help:
- Review the test classes for expected behavior
- Check the documentation links provided
- Reach out to your instructor

---
Happy coding! 🚀

*This is part of the Cloud Code Academy Integration Developer certification program.*

## Copyright

© 2025 Cloud Code. All rights reserved.

This software is provided under the Cloud Code Developer Kickstart Program License (CCDKPL) Version 1.0.
The software is licensed, not sold, and is intended for personal educational purposes only as part of the Cloud Code Developer Kickstart Program.

See the full license terms in LICENSE.md for more details regarding usage restrictions, ownership, warranties, and limitations of liability.