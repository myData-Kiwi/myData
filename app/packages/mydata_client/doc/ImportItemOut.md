# mydata_client.model.ImportItemOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**action** | **String** | what the commit does unless chosen otherwise: import, update, link (keep the matching contact of yours and hide the followed copy) or skip | 
**choices** | **List<String>** | the actions this card may be given | [default to const []]
**convertedFrom** | **String** | 2.1 for a vCard 2.1 stored as 3.0 | [optional] 
**displayName** | **String** |  | 
**entry** | **String** | the zip entry the card came from (a name only) | [optional] 
**index** | **int** | the card's position in the input, from 0 | 
**kind** | **String** | individual, org or group; null for a card not read | [optional] 
**matches** | [**List<ImportMatchOut>**](ImportMatchOut.md) |  | [optional] [default to const []]
**reason** | **String** | conflict: edited, merged or kept_yours; skipped: unreadable, no_end, version, empty, too_large (cards past the first 50000 are counted only, with no item) | [optional] 
**status** | **String** | new, duplicate, in_file, unchanged, update, conflict, deleted, skipped | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


