# mydata_client.model.ImportMatchOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**accountId** | **String** |  | [optional] 
**contactId** | **String** |  | [optional] 
**displayName** | **String** |  | 
**itemIndex** | **int** | for source file: the earlier card's index | [optional] 
**signals** | **List<String>** | origin, changed (a card with no UID that changed since it was imported), uid, identical, email, phone, name | [default to const []]
**source_** | **String** | mydata (owned), icloud, mac, or file (an earlier card in the same input) | 
**strength** | **String** | same_origin (imported from this card before), strong (same email or phone, and the same name or none), suggestion (the same name only, or an email or phone shared under another name: never acted on) | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


