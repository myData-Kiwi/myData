# mydata_client.model.ImportCountsOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**cards** | **int** | cards in the input, read or not | 
**conflicts** | **int** | cards imported before that changed, the owned copy edited (or merged) since: not written | 
**contacts** | **int** | cards that are contacts (people and organisations) | 
**created** | **int** | after the commit: contacts created | [optional] 
**deleted** | **int** | cards imported before whose owned copy is in Recently deleted | 
**duplicates** | **int** | cards whose email or phone an owned contact of the same name already has | 
**followedMatches** | **int** | cards whose email or phone a followed contact has | 
**groups** | **int** | group cards: imported as groups, never listed as contacts | 
**groupsCreated** | **int** |  | [optional] 
**inFile** | **int** | cards repeated in the input | 
**linked** | **int** |  | [optional] 
**missing** | **int** | contacts earlier imports from this source brought in that the input no longer has (reported, never deleted) | 
**new_** | **int** |  | 
**notWritten** | **int** |  | [optional] 
**skipped** | **int** | cards that could not be read (the loss report says why) | 
**suggestions** | **int** | cards with a contact of the same name only (a suggestion) | 
**toImport** | **int** |  | 
**toLink** | **int** |  | 
**toUpdate** | **int** |  | 
**unchanged** | **int** | cards imported before, unchanged | 
**updated** | **int** |  | [optional] 
**updates** | **int** | cards imported before that changed, the owned copy unedited since | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


