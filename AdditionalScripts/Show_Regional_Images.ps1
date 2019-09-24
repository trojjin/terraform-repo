#
$locname=Get-AzureRmLocation | `
select displayname | `
Out-GridView -PassThru -Title "Choose a location"
#
$pubname=Get-AzureRmVMImagePublisher `
-Location $locname.DisplayName | `
Out-GridView -PassThru -Title "Choose a publisher"
#
$offername = Get-AzureRmVMImageOffer `
-Location $locname.DisplayName `
-PublisherName $pubname.PublisherName | `
Out-GridView -PassThru -Title "Choose an offer"
#
$title="SKUs for location: " + `
$locname.DisplayName + `
", Publisher: " + `
$pubname.PublisherName + `
", Offer: " + `
$offername.Offer
 
Get-AzureRmVMImageSku `
-Location $locname.DisplayName `
-PublisherName $pubname.PublisherName `
-Offer $offername.Offer | `
select SKUS | `
Out-GridView -Title $title