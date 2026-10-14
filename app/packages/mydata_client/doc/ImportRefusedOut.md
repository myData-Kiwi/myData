# mydata_client.model.ImportRefusedOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**code** | **String** | a whole file refused (400, 413): too_big (over 50 MB), zip_too_big (the zip expands to over 200 MB), zip_entry_too_big (a file in the zip expands far more than a vCard does), zip_too_many (over 10,000 files in the zip), zip_unreadable, zip_no_vcard (no .vcf in the zip), no_vcard (no vCard in the file), utf16_unreadable. A commit refused (400): losses_not_accepted, choice_refused (a choice a card cannot take now: read the preview again) | 
**detail** | **String** | for logs and the command line; the apps write their own sentence from code | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


