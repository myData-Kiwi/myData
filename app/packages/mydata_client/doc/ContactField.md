# mydata_client.model.ContactField

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**address** | [**PostalAddress**](PostalAddress.md) | an address's parts, to lay it out in the locale's order; only for kind address | [optional] 
**label** | **String** | the source's label in sentence case (\"Mobile\", \"Home fax\"), or a label the user typed, exactly as written; empty when none | [optional] [default to '']
**value** | **String** | as the source wrote it. Birthday: YYYY-MM-DD, or --MM-DD when the year is not known. Address: plain lines (street, then locality, region and postal code, then country); `address` has the parts | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


