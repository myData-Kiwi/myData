# mydata_client.model.MergePreviewOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**contact** | [**CardValuesOut**](CardValuesOut.md) | the contact the merge would make (not stored) | 
**leftOut** | [**List<MergeLeftOutValueOut>**](MergeLeftOutValueOut.md) | each value of the others it would not hold (a different value of a single one, such as a second birthday or job title, or what kind of card it is): it stays with the originals in Recently deleted | [optional] [default to const []]
**namesFrom** | **String** | the contact whose name and details it starts from | 
**newest** | **String** | the contact changed most recently: the default for names_from | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


