# mydata_client.api.AssistantApi

## Load the API package
```dart
import 'package:mydata_client/api.dart';
```

All URIs are relative to *http://127.0.0.1:47821*

Method | HTTP request | Description
------------- | ------------- | -------------
[**assistantSettings**](AssistantApi.md#assistantsettings) | **PUT** /assistant/settings | Assistant Settings
[**messages**](AssistantApi.md#messages) | **POST** /assistant/messages | Messages


# **assistantSettings**
> StatusOut assistantSettings(assistantSettingsIn)

Assistant Settings

Switch the assistant on (the model is prepared, downloading it if needed) or off (nothing is downloaded or loaded; the rest of myData works without it).

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = AssistantApi();
final assistantSettingsIn = AssistantSettingsIn(); // AssistantSettingsIn | 

try {
    final result = api_instance.assistantSettings(assistantSettingsIn);
    print(result);
} catch (e) {
    print('Exception when calling AssistantApi->assistantSettings: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **assistantSettingsIn** | [**AssistantSettingsIn**](AssistantSettingsIn.md)|  | 

### Return type

[**StatusOut**](StatusOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **messages**
> String messages(messageIn)

Messages

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = AssistantApi();
final messageIn = MessageIn(); // MessageIn | 

try {
    final result = api_instance.messages(messageIn);
    print(result);
} catch (e) {
    print('Exception when calling AssistantApi->messages: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **messageIn** | [**MessageIn**](MessageIn.md)|  | 

### Return type

**String**

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: text/event-stream, application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

