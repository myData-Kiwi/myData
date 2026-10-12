# mydata_client.model.AppearanceOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**chosen** | **bool** | false until someone has chosen a theme; first run offers the choice | 
**theme** | **String** | the theme every app uses; mode is per device and not stored here | 
**themes** | [**List<ThemeOut>**](ThemeOut.md) | every theme, in the order to show them | [default to const []]

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


