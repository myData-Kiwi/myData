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
**signals** | **List<String>** | origin, uid, identical, email, phone, name | [default to const []]
**source_** | **String** | mydata (owned), icloud, mac, or file (an earlier card in the same input) | 
**strength** | **String** | same_origin (imported from this card before), strong (same email or phone), suggestion (same name only: never acted on) | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


