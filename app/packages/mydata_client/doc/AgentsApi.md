# mydata_client.api.AgentsApi

## Load the API package
```dart
import 'package:mydata_client/api.dart';
```

All URIs are relative to *http://127.0.0.1:47821*

Method | HTTP request | Description
------------- | ------------- | -------------
[**agents**](AgentsApi.md#agents) | **GET** /agents | Agents
[**createAgent**](AgentsApi.md#createagent) | **POST** /agents | Create Agent
[**revokeAgent**](AgentsApi.md#revokeagent) | **DELETE** /agents/{agent_id} | Revoke Agent


# **agents**
> List<AgentOut> agents()

Agents

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = AgentsApi();

try {
    final result = api_instance.agents();
    print(result);
} catch (e) {
    print('Exception when calling AgentsApi->agents: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**List<AgentOut>**](AgentOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **createAgent**
> AgentCreated createAgent(agentIn)

Create Agent

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = AgentsApi();
final agentIn = AgentIn(); // AgentIn | 

try {
    final result = api_instance.createAgent(agentIn);
    print(result);
} catch (e) {
    print('Exception when calling AgentsApi->createAgent: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **agentIn** | [**AgentIn**](AgentIn.md)|  | 

### Return type

[**AgentCreated**](AgentCreated.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **revokeAgent**
> AgentOut revokeAgent(agentId)

Revoke Agent

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = AgentsApi();
final agentId = agentId_example; // String | 

try {
    final result = api_instance.revokeAgent(agentId);
    print(result);
} catch (e) {
    print('Exception when calling AgentsApi->revokeAgent: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **agentId** | **String**|  | 

### Return type

[**AgentOut**](AgentOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

