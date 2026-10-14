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
**followedMatches** | **int** | a file's cards that hide a followed contact once imported (the same name and the same email or phone, emails in lower case and phones in E.164) with the default choices (imported, updated or found unchanged): each person is then one result. Matches with hides say which. 0 for a copy of an account (it hides its own cards) | 
**groups** | **int** | group cards: imported as groups, never listed as contacts | 
**groupsCreated** | **int** |  | [optional] 
**hidden** | **int** | after the commit of a file: followed contacts now hidden behind the contacts it wrote (or found unchanged) | [optional] 
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


