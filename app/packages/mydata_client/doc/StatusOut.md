# mydata_client.model.StatusOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**agentsConnected** | **int** | agent tokens used in the last five minutes | 
**apiVersion** | **String** | a hash of this host's API (its routes and schemas); an app built against another API version replaces the host | 
**assistantEnabled** | **bool** | false when the user switched the assistant off | 
**backup** | [**BackupOut**](BackupOut.md) | snapshots of the databases and the last restore drill | [optional] 
**conversationEpoch** | **int** | moves on by one at every switch between demo and real mode, which ends every conversation: an app that sees it change starts a new conversation and says why | 
**demoDate** | **bool** | true while today is pinned to the demo data's date | 
**lastError** | [**ErrorOut**](ErrorOut.md) |  | [optional] 
**macAvailable** | **bool** | true on a Mac host: the This Mac source exists | [optional] [default to false]
**memory** | [**MemoryOut**](MemoryOut.md) |  | 
**mode** | **String** | real when a source is on (an account is linked, or This Mac is turned on) or the host owns data (an address book or calendar of its own): the tools serve that data, with the real date; demo otherwise: the tools serve fake data and the date is pinned | 
**model** | [**ModelOut**](ModelOut.md) |  | 
**ready** | **bool** | true when the assistant can answer | 
**stale** | **bool** | true when the host's code on disk changed since it started; an app replaces it when the code on disk is the API it was built against | [optional] [default to false]
**theme** | **String** | deprecated, kept for one release: the theme the host gave every app before themes were chosen on each device; an app reads it once, to seed that device's choice | 
**today** | **String** | the date the host treats as today | 
**uptimeSeconds** | **num** |  | 
**version** | **String** |  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


