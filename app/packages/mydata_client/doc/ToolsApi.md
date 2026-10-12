# mydata_client.api.ToolsApi

## Load the API package
```dart
import 'package:mydata_client/api.dart';
```

All URIs are relative to *http://127.0.0.1:47821*

Method | HTTP request | Description
------------- | ------------- | -------------
[**tools**](ToolsApi.md#tools) | **GET** /tools | Tools


# **tools**
> List<ToolOut> tools()

Tools

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = ToolsApi();

try {
    final result = api_instance.tools();
    print(result);
} catch (e) {
    print('Exception when calling ToolsApi->tools: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**List<ToolOut>**](ToolOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

