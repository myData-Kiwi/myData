# mydata_client.model.ImportCommittedOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**addressBookId** | **String** |  | [optional] 
**conflicts** | [**List<ImportConflictOut>**](ImportConflictOut.md) |  | [optional] [default to const []]
**counts** | **Map<String, Object>** | as ImportCountsOut, plus undo (removed, reverted, unlinked, kept, gone) once undone | [default to const {}]
**finishedAt** | **String** |  | [optional] 
**id** | **String** |  | 
**label** | **String** |  | 
**missing** | [**List<ImportMissingOut>**](ImportMissingOut.md) |  | [optional] [default to const []]
**source_** | **String** |  | 
**sourceAccount** | **String** |  | [optional] 
**startedAt** | **String** |  | 
**status** | **String** | committed or undone | 
**stopFollowing** | [**StopFollowingOut**](StopFollowingOut.md) |  | [optional] 
**undoneAt** | **String** |  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


