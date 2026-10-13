# mydata_client.api.SourcesApi

## Load the API package
```dart
import 'package:mydata_client/api.dart';
```

All URIs are relative to *http://127.0.0.1:47821*

Method | HTTP request | Description
------------- | ------------- | -------------
[**accounts**](SourcesApi.md#accounts) | **GET** /accounts | Accounts
[**addAccount**](SourcesApi.md#addaccount) | **POST** /accounts | Add Account
[**calendars**](SourcesApi.md#calendars) | **GET** /calendars | Calendars
[**contact**](SourcesApi.md#contact) | **GET** /contacts/{contact_id} | Contact
[**contacts**](SourcesApi.md#contacts) | **GET** /contacts | Contacts
[**events**](SourcesApi.md#events) | **GET** /events | Events
[**removeAccount**](SourcesApi.md#removeaccount) | **DELETE** /accounts/{account_id} | Remove Account
[**syncAccount**](SourcesApi.md#syncaccount) | **POST** /accounts/{account_id}/sync | Sync Account
[**syncStatus**](SourcesApi.md#syncstatus) | **GET** /sync | Sync Status


# **accounts**
> List<AccountOut> accounts()

Accounts

Linked accounts. Passwords are never returned.

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = SourcesApi();

try {
    final result = api_instance.accounts();
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->accounts: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**List<AccountOut>**](AccountOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **addAccount**
> AccountOut addAccount(accountIn)

Add Account

Link an account. The provider checks the email and password first (discovery); nothing is stored unless that succeeds. Then the host mirrors its contacts and calendars, read-only, and switches to real mode.

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = SourcesApi();
final accountIn = AccountIn(); // AccountIn | 

try {
    final result = api_instance.addAccount(accountIn);
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->addAccount: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **accountIn** | [**AccountIn**](AccountIn.md)|  | 

### Return type

[**AccountOut**](AccountOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **calendars**
> List<CalendarOut> calendars()

Calendars

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = SourcesApi();

try {
    final result = api_instance.calendars();
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->calendars: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**List<CalendarOut>**](CalendarOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **contact**
> ContactDetailOut contact(contactId, raw)

Contact

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = SourcesApi();
final contactId = contactId_example; // String | 
final raw = true; // bool | include the raw vCard

try {
    final result = api_instance.contact(contactId, raw);
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->contact: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **contactId** | **String**|  | 
 **raw** | **bool**| include the raw vCard | [optional] [default to false]

### Return type

[**ContactDetailOut**](ContactDetailOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **contacts**
> List<ContactOut> contacts(query, limit, offset)

Contacts

Mirrored contacts by name, or the ones matching `query` (every word, as a prefix).

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = SourcesApi();
final query = query_example; // String | search names, organisation, emails and phones
final limit = 56; // int | 
final offset = 56; // int | 

try {
    final result = api_instance.contacts(query, limit, offset);
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->contacts: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **query** | **String**| search names, organisation, emails and phones | [optional] 
 **limit** | **int**|  | [optional] [default to 100]
 **offset** | **int**|  | [optional] [default to 0]

### Return type

[**List<ContactOut>**](ContactOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **events**
> List<EventOut> events(start, end, calendar)

Events

Events overlapping the days from start to end (both included), in the host's time zone, with recurring events expanded into occurrences.

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = SourcesApi();
final start = 2013-10-20; // DateTime | first day, YYYY-MM-DD
final end = 2013-10-20; // DateTime | last day, YYYY-MM-DD (included)
final calendar = []; // List<String> | calendar ids; repeat for several. Omit for every calendar

try {
    final result = api_instance.events(start, end, calendar);
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->events: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **start** | **DateTime**| first day, YYYY-MM-DD | 
 **end** | **DateTime**| last day, YYYY-MM-DD (included) | 
 **calendar** | [**List<String>**](String.md)| calendar ids; repeat for several. Omit for every calendar | [optional] [default to const []]

### Return type

[**List<EventOut>**](EventOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **removeAccount**
> AccountOut removeAccount(accountId)

Remove Account

Unlink an account: its mirrored contacts and calendars and its Keychain item are deleted. Nothing changes at the provider. With no account left the host returns to demo mode.

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = SourcesApi();
final accountId = accountId_example; // String | 

try {
    final result = api_instance.removeAccount(accountId);
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->removeAccount: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **accountId** | **String**|  | 

### Return type

[**AccountOut**](AccountOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **syncAccount**
> AccountSyncOut syncAccount(accountId)

Sync Account

Sync now: the account is synced next, in the background. Follow it with GET /sync.

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = SourcesApi();
final accountId = accountId_example; // String | 

try {
    final result = api_instance.syncAccount(accountId);
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->syncAccount: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **accountId** | **String**|  | 

### Return type

[**AccountSyncOut**](AccountSyncOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **syncStatus**
> SyncOut syncStatus()

Sync Status

The mode, and each account's sync status.

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = SourcesApi();

try {
    final result = api_instance.syncStatus();
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->syncStatus: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**SyncOut**](SyncOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

