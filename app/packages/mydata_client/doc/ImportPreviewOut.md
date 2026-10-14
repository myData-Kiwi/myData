# mydata_client.model.ImportPreviewOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**accountId** | **String** |  | [optional] 
**changes** | [**List<ImportNoteOut>**](ImportNoteOut.md) | what is stored differently without being lost | [default to const []]
**counts** | [**ImportCountsOut**](ImportCountsOut.md) |  | 
**expiresAt** | **String** |  | 
**id** | **String** | the preview's id, held by the host until expires_at (not across a restart) | 
**items** | [**List<ImportItemOut>**](ImportItemOut.md) |  | [default to const []]
**label** | **String** | the file's name, or the source as a heading | 
**losses** | [**List<ImportNoteOut>**](ImportNoteOut.md) | what in the input will not reach the host; when not empty, commit needs accept_losses | [default to const []]
**missing** | [**List<ImportMissingOut>**](ImportMissingOut.md) |  | [default to const []]
**needsAcceptance** | **bool** |  | 
**source_** | **String** | file, or icloud for a copy of a followed iCloud account | 
**stopFollowing** | [**StopFollowingOut**](StopFollowingOut.md) | for a copy of a followed account: the app may offer to stop following it | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


