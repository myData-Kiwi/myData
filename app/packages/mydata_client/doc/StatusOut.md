# mydata_client.model.StatusOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**agentsConnected** | **int** | agent tokens used in the last five minutes | 
**assistantEnabled** | **bool** | false when the user switched the assistant off | 
**demoDate** | **bool** | true while today is pinned to the demo data's date | 
**lastError** | [**ErrorOut**](ErrorOut.md) |  | [optional] 
**memory** | [**MemoryOut**](MemoryOut.md) |  | 
**model** | [**ModelOut**](ModelOut.md) |  | 
**ready** | **bool** | true when the assistant can answer | 
**theme** | **String** | the theme every app uses; mode is per device and not stored here | 
**today** | **String** | the date the host treats as today | 
**uptimeSeconds** | **num** |  | 
**version** | **String** |  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


