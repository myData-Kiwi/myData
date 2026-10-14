# mydata_client.model.ImportUndoneOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**gone** | **int** | contacts already in Recently deleted or deleted for good | 
**groupsRemoved** | **int** | group cards it created, now in Recently deleted with them | [optional] [default to 0]
**kept** | [**List<ImportMissingOut>**](ImportMissingOut.md) | contacts changed since the import: left as they are | [default to const []]
**removed** | **int** | contacts it created, now in Recently deleted | 
**reverted** | **int** | contacts it updated, back to their earlier text | 
**summary** | [**ImportOut**](ImportOut.md) | the import as it is now (status undone) | 
**unlinked** | **int** |  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


