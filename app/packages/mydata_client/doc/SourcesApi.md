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
[**configureMac**](SourcesApi.md#configuremac) | **PUT** /sources/mac | Configure Mac
[**contact**](SourcesApi.md#contact) | **GET** /contacts/{contact_id} | Contact
[**contactPhoto**](SourcesApi.md#contactphoto) | **GET** /contacts/{contact_id}/photo | Contact Photo
[**contacts**](SourcesApi.md#contacts) | **GET** /contacts | Contacts
[**createContact**](SourcesApi.md#createcontact) | **POST** /contacts | Create Contact
[**deleteContact**](SourcesApi.md#deletecontact) | **DELETE** /contacts/{contact_id} | Delete Contact
[**events**](SourcesApi.md#events) | **GET** /events | Events
[**purgeItem**](SourcesApi.md#purgeitem) | **DELETE** /trash/{item_id} | Purge Item
[**removeAccount**](SourcesApi.md#removeaccount) | **DELETE** /accounts/{account_id} | Remove Account
[**requestMacAccess**](SourcesApi.md#requestmacaccess) | **POST** /sources/mac/request-access | Request Mac Access
[**restoreItem**](SourcesApi.md#restoreitem) | **POST** /trash/{item_id}/restore | Restore Item
[**setMacReader**](SourcesApi.md#setmacreader) | **PUT** /sources/mac/reader | Set Mac Reader
[**sources**](SourcesApi.md#sources) | **GET** /sources | Sources
[**syncAccount**](SourcesApi.md#syncaccount) | **POST** /accounts/{account_id}/sync | Sync Account
[**syncMac**](SourcesApi.md#syncmac) | **POST** /sources/mac/sync | Sync Mac
[**syncStatus**](SourcesApi.md#syncstatus) | **GET** /sync | Sync Status
[**trash**](SourcesApi.md#trash) | **GET** /trash | Trash
[**undo**](SourcesApi.md#undo) | **POST** /undo/{undo_id} | Undo
[**updateContact**](SourcesApi.md#updatecontact) | **PATCH** /contacts/{contact_id} | Update Contact


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

Every mirrored calendar, grouped by source: This Mac first, then each iCloud account. The same calendar seen through This Mac and through an iCloud account is listed twice, once per source.

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

# **configureMac**
> SourceOut configureMac(macSourceIn)

Configure Mac

Turn This Mac on or off, and choose which contact accounts and calendars it includes (null: all). Fields left out keep their value. Turning it off stops its reader and deletes everything it mirrored; leaving out an account or calendar deletes what was mirrored from it. Copies in the host's snapshots stay until they expire (within 12 months while the host runs). With no source on, the host is back in demo mode.

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
final macSourceIn = MacSourceIn(); // MacSourceIn | 

try {
    final result = api_instance.configureMac(macSourceIn);
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->configureMac: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **macSourceIn** | [**MacSourceIn**](MacSourceIn.md)|  | 

### Return type

[**SourceOut**](SourceOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **contact**
> ContactDetailOut contact(contactId, raw)

Contact

One contact, for its page: the fields grouped by kind, the job title and where the card comes from; whether it can be changed here, and its etag (also the ETag header).

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

# **contactPhoto**
> MultipartFile contactPhoto(contactId)

Contact Photo

The contact's photo, as JPEG or PNG. 404 when there is none: the app shows initials.

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

try {
    final result = api_instance.contactPhoto(contactId);
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->contactPhoto: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **contactId** | **String**|  | 

### Return type

[**MultipartFile**](MultipartFile.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: image/jpeg, image/png, application/json

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

# **createContact**
> ContactWriteOut createContact(contactIn)

Create Contact

Create a contact the host owns, in its \"myData\" address book (made with the first contact, which also switches the host to real mode). It is on myData only, not on any phone yet (on_phone false).

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
final contactIn = ContactIn(); // ContactIn | 

try {
    final result = api_instance.createContact(contactIn);
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->createContact: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **contactIn** | [**ContactIn**](ContactIn.md)|  | 

### Return type

[**ContactWriteOut**](ContactWriteOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteContact**
> ContactWriteOut deleteContact(contactId, ifMatch)

Delete Contact

Move an owned contact to Recently deleted. It is deleted for good after 30 days (purge_after); until then POST /trash/{id}/restore or the undo id brings it back. Refused with 412 when the contact changed since its etag. Copies in the host's snapshots stay until those expire (within 12 months while the host runs).

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
final ifMatch = ifMatch_example; // String | the etag of the contact the user chose to delete

try {
    final result = api_instance.deleteContact(contactId, ifMatch);
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->deleteContact: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **contactId** | **String**|  | 
 **ifMatch** | **String**| the etag of the contact the user chose to delete | [optional] 

### Return type

[**ContactWriteOut**](ContactWriteOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **events**
> EventsOut events(start, end, calendar)

Events

Events overlapping the days from start to end (both included), in the host's time zone, with recurring events expanded into occurrences; and, per source, which of those days it holds. This Mac holds a window (one year back, two ahead): days outside it are unknown, not empty.

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
final calendar = []; // List<String?> | calendar ids; repeat for several. Omit for every calendar

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
 **calendar** | [**List<String?>**](String.md)| calendar ids; repeat for several. Omit for every calendar | [optional] [default to const []]

### Return type

[**EventsOut**](EventsOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **purgeItem**
> purgeItem(itemId, ifMatch)

Purge Item

Delete an item in Recently deleted for good now, with its earlier versions; it cannot be brought back or undone. Refused with 412 when the item changed since its etag (restored, changed and deleted again elsewhere): look at it again first. The host log records which app asked. Copies in the host's snapshots stay until those expire (backups_kept_until).

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
final itemId = itemId_example; // String | 
final ifMatch = ifMatch_example; // String | the item's etag as Recently deleted lists it (contact.etag)

try {
    api_instance.purgeItem(itemId, ifMatch);
} catch (e) {
    print('Exception when calling SourcesApi->purgeItem: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **ifMatch** | **String**| the item's etag as Recently deleted lists it (contact.etag) | [optional] 

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **removeAccount**
> AccountOut removeAccount(accountId)

Remove Account

Unlink an account: its mirrored contacts and calendars and its Keychain item are deleted. Copies in the host's snapshots stay until they expire (within 12 months while the host runs). Nothing changes at the provider. With no account left the host returns to demo mode.

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

# **requestMacAccess**
> SourceOut requestMacAccess(accessIn)

Request Mac Access

Show the system's permission prompt for contacts or calendars. Only call this when the user pressed Allow. Waits for the answer (up to a few minutes) and returns the source with the new status.

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
final accessIn = AccessIn(); // AccessIn | 

try {
    final result = api_instance.requestMacAccess(accessIn);
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->requestMacAccess: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **accessIn** | [**AccessIn**](AccessIn.md)|  | 

### Return type

[**SourceOut**](SourceOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **restoreItem**
> ContactWriteOut restoreItem(itemId, ifMatch)

Restore Item

Bring an item back from Recently deleted. 404 when it is not there (or was deleted for good); 412 when If-Match is sent and the item changed since.

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
final itemId = itemId_example; // String | 
final ifMatch = ifMatch_example; // String | optional: the item's etag as Recently deleted lists it; refuse if it changed since

try {
    final result = api_instance.restoreItem(itemId, ifMatch);
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->restoreItem: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **itemId** | **String**|  | 
 **ifMatch** | **String**| optional: the item's etag as Recently deleted lists it; refuse if it changed since | [optional] 

### Return type

[**ContactWriteOut**](ContactWriteOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setMacReader**
> SourceOut setMacReader(readerIn)

Set Mac Reader

Where the myData app's reader helper is (myData.app/Contents/Helpers/myDataReader.app). The myData app sends this at start; the host checks it is the reader before using it.

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
final readerIn = ReaderIn(); // ReaderIn | 

try {
    final result = api_instance.setMacReader(readerIn);
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->setMacReader: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **readerIn** | [**ReaderIn**](ReaderIn.md)|  | 

### Return type

[**SourceOut**](SourceOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **sources**
> SourcesOut sources()

Sources

Every source: This Mac first (only on a Mac host), then each linked iCloud account.

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
    final result = api_instance.sources();
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->sources: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**SourcesOut**](SourcesOut.md)

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

# **syncMac**
> SourceOut syncMac()

Sync Mac

Read the Mac's contacts and calendars again now, in the background.

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
    final result = api_instance.syncMac();
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->syncMac: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**SourceOut**](SourceOut.md)

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

# **trash**
> List<TrashItemOut> trash(kind)

Trash

Recently deleted: what was deleted in the apps, the most recent first, with when each is deleted for good. Copies in the host's snapshots stay until those expire.

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
final kind = kind_example; // String | what to list

try {
    final result = api_instance.trash(kind);
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->trash: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **kind** | **String**| what to list | [optional] [default to 'contact']

### Return type

[**List<TrashItemOut>**](TrashItemOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **undo**
> UndoOut undo(undoId)

Undo

Undo one change by its undo id. The undo is a new change: it is refused when the item changed since (nothing later is ever overwritten), and a change is undone at most once, also across a restart.

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
final undoId = undoId_example; // String | 

try {
    final result = api_instance.undo(undoId);
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->undo: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **undoId** | **String**|  | 

### Return type

[**UndoOut**](UndoOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateContact**
> ContactWriteOut updateContact(contactId, contactIn, ifMatch)

Update Contact

Change an owned contact. Only the fields in the body change (null clears one), and of the card only the lines whose values change are written. Refused with 412 when the contact changed since its etag.

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
final contactIn = ContactIn(); // ContactIn | 
final ifMatch = ifMatch_example; // String | the etag the change was made from

try {
    final result = api_instance.updateContact(contactId, contactIn, ifMatch);
    print(result);
} catch (e) {
    print('Exception when calling SourcesApi->updateContact: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **contactId** | **String**|  | 
 **contactIn** | [**ContactIn**](ContactIn.md)|  | 
 **ifMatch** | **String**| the etag the change was made from | [optional] 

### Return type

[**ContactWriteOut**](ContactWriteOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

