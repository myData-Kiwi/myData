# mydata_client.api.ImportsApi

## Load the API package
```dart
import 'package:mydata_client/api.dart';
```

All URIs are relative to *http://127.0.0.1:47821*

Method | HTTP request | Description
------------- | ------------- | -------------
[**commitImport**](ImportsApi.md#commitimport) | **POST** /import/previews/{preview_id}/commit | Commit Import
[**importHistory**](ImportsApi.md#importhistory) | **GET** /imports | Import History
[**importPreview**](ImportsApi.md#importpreview) | **GET** /import/previews/{preview_id} | Import Preview
[**previewContactsImport**](ImportsApi.md#previewcontactsimport) | **POST** /import/contacts/preview | Preview Contacts Import
[**previewSourceImport**](ImportsApi.md#previewsourceimport) | **POST** /import/contacts/from-source/{account_id}/preview | Preview Source Import
[**undoImport**](ImportsApi.md#undoimport) | **POST** /imports/{import_id}/undo | Undo Import


# **commitImport**
> ImportCommittedOut commitImport(previewId, importCommitIn)

Commit Import

Import the preview as one batch into an owned address book, after a snapshot of the databases. Each card gets its default action unless `choices` names another; nothing is merged. A preview with losses needs accept_losses. Cards that changed both in the input and on the host since an earlier import are reported as conflicts and not written; contacts an earlier import brought in that the input no longer has are reported as missing and kept. POST /imports/{id}/undo undoes the whole import.

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = ImportsApi();
final previewId = previewId_example; // String | 
final importCommitIn = ImportCommitIn(); // ImportCommitIn | 

try {
    final result = api_instance.commitImport(previewId, importCommitIn);
    print(result);
} catch (e) {
    print('Exception when calling ImportsApi->commitImport: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **previewId** | **String**|  | 
 **importCommitIn** | [**ImportCommitIn**](ImportCommitIn.md)|  | 

### Return type

[**ImportCommittedOut**](ImportCommittedOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **importHistory**
> List<ImportOut> importHistory()

Import History

Every import, the newest first: when, from where, its counts and whether it was undone.

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = ImportsApi();

try {
    final result = api_instance.importHistory();
    print(result);
} catch (e) {
    print('Exception when calling ImportsApi->importHistory: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**List<ImportOut>**](ImportOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **importPreview**
> ImportPreviewOut importPreview(previewId)

Import Preview

A preview again, analysed as the host is now.

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = ImportsApi();
final previewId = previewId_example; // String | 

try {
    final result = api_instance.importPreview(previewId);
    print(result);
} catch (e) {
    print('Exception when calling ImportsApi->importPreview: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **previewId** | **String**|  | 

### Return type

[**ImportPreviewOut**](ImportPreviewOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **previewContactsImport**
> ImportPreviewOut previewContactsImport(body, filename)

Preview Contacts Import

Read a .vcf (vCard 2.1, 3.0 or 4.0) or a .zip of them, sent as the request body, into a preview held for an hour: counts, every card's status and default action, matches with your contacts and followed ones, the loss report and what changes. Nothing is written. The zip is read in memory, never extracted.

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = ImportsApi();
final body = MultipartFile(); // MultipartFile | the file's bytes as they are (a .vcf, or a .zip of .vcf files), at most 50 MB
final filename = filename_example; // String | the file's name, shown in the history; never opened as a path

try {
    final result = api_instance.previewContactsImport(body, filename);
    print(result);
} catch (e) {
    print('Exception when calling ImportsApi->previewContactsImport: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **body** | **MultipartFile**| the file's bytes as they are (a .vcf, or a .zip of .vcf files), at most 50 MB | 
 **filename** | **String**| the file's name, shown in the history; never opened as a path | [optional] [default to '']

### Return type

[**ImportPreviewOut**](ImportPreviewOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/octet-stream
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **previewSourceImport**
> ImportPreviewOut previewSourceImport(accountId)

Preview Source Import

A preview of importing a copy of a followed iCloud account's contacts (as the mirror holds them, so nothing is lost). Once imported, each followed card is hidden behind its owned copy while the account is still followed; stop_following says the account can be unfollowed. This Mac is never imported (409).

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = ImportsApi();
final accountId = accountId_example; // String | 

try {
    final result = api_instance.previewSourceImport(accountId);
    print(result);
} catch (e) {
    print('Exception when calling ImportsApi->previewSourceImport: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **accountId** | **String**|  | 

### Return type

[**ImportPreviewOut**](ImportPreviewOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **undoImport**
> ImportUndoneOut undoImport(importId)

Undo Import

Undo a whole import: what it created and nobody changed since goes to Recently deleted, what it updated gets its earlier text back. Anything changed since is kept and listed. Nothing is deleted for good. Works once, also after a restart.

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = ImportsApi();
final importId = importId_example; // String | 

try {
    final result = api_instance.undoImport(importId);
    print(result);
} catch (e) {
    print('Exception when calling ImportsApi->undoImport: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **importId** | **String**|  | 

### Return type

[**ImportUndoneOut**](ImportUndoneOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

