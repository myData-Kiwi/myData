# mydata_client.api.HostApi

## Load the API package
```dart
import 'package:mydata_client/api.dart';
```

All URIs are relative to *http://127.0.0.1:47821*

Method | HTTP request | Description
------------- | ------------- | -------------
[**retry**](HostApi.md#retry) | **POST** /model/retry | Retry
[**shutdownHost**](HostApi.md#shutdownhost) | **POST** /shutdown | Shutdown Host
[**status**](HostApi.md#status) | **GET** /status | Status


# **retry**
> StatusOut retry()

Retry

Try again to get the model ready (after an error, or once Ollama is installed).

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = HostApi();

try {
    final result = api_instance.retry();
    print(result);
} catch (e) {
    print('Exception when calling HostApi->retry: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**StatusOut**](StatusOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **shutdownHost**
> Map<String, Object?> shutdownHost()

Shutdown Host

Stop the host. Only the myData app (which owns the host's lifetime) and the mydata command may.

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = HostApi();

try {
    final result = api_instance.shutdownHost();
    print(result);
} catch (e) {
    print('Exception when calling HostApi->shutdownHost: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

**Map<String, Object?>**

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **status**
> StatusOut status()

Status

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = HostApi();

try {
    final result = api_instance.status();
    print(result);
} catch (e) {
    print('Exception when calling HostApi->status: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**StatusOut**](StatusOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

