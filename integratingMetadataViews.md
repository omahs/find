# How to add rich metadata to your NFT on .Find

Implementing [MetadataViews](./contracts/standard/MetadataViews.cdc) correctly in NFT smart contracts enables DApps on flow to extract rich NFT metadata and display them on [.Find](find.xyz). With MetadataViews, data such as display thumbnail, name, description, traits, collection information can be showcased in the exact way it is expected. 

We advice anybody that is integrating to contact us in [discord in the technical channel](https://discord.gg/8a27XMx8Zp) 


## Implementing `MetadataViews.Display`
For .Find to display an asset, the smart contract MUST implement `MetadataViews.Display`
.Find gets the display information through resolving Display View. 
Let's take a closer look on code implementation. 

```cadence

pub fun resolveView(_ type: Type): AnyStruct? {
	switch type {

		// Example for Display 
		case Type<MetadataViews.Display>() : 

			return MetadataViews.Display(
				name: NFT name, // Type<String>
				description: NFT description, // Type<String>
				thumbnail: NFT thumbnail // Type<{MetadataViews.File}>
			)

	}
}

```

If the thumbnail is a HTTP resource 
```cadence 
thumbnail : MetadataViews.HTTPFile(url: *Please put your url here)
```

If the thumbnail is an IPFS resource
```cadence 
//
thumbnail : MetadataViews.IPFSFile(
	cid: thumbnail cid, // Type <String>
	path: ipfs path // Type <String?> specify path if the cid is a folder hash, otherwise use nil here
)
```


![MetadataViews.Display](/images/display.png "Display")

| Param      | Description |
| ----------- | ----------- |
| name   | Name of the NFT        |
| description      | Human readable description of the NFT      |
| thumbnail      | A small thumbnail representation of the object       |

## Implementing `MetadataViews.CollectionDisplay`

.Find will resolve this MetadataViews struct for marketplace collection display from NFT Catalog. A rich and appropriata collection display will improve in UX when user browse your collection. 

To enable a decent collection display, the specific NFT that implements MetadataViews.CollectionDisplay should be submitted to [NFT-Catalog](https://nft-catalog.vercel.app/catalog/mainnet) for approval. 

```cadence

pub fun resolveView(_ type: Type): AnyStruct? {
	switch type {

		// Example for NFTCollectionDisplay 
		case Type<MetadataViews.NFTCollectionDisplay>() : 

			return MetadataViews.NFTCollectionDisplay(
            name: collection name,  // Type<String>
            description: collection description,  // Type<String>
            externalURL: External url of the collection,  // Type<MetadataViews.ExternalURL>
            squareImage: square image,  // Type<MetadataViews.ExternalURL>
            bannerImage: banner image,  // Type<MetadataViews.ExternalURL>
            socials: { 
				"Twitter" : ExternalURL ,
				"Discord" : ExternalURL ,
				"Instagram" : ExternalURL ,
				"Facebook" : ExternalURL ,
				"TikTok" : ExternalURL ,
				"LinkedIn" : ExternalURL 
			}                           // Type<{String : MetadataViews.ExternalURL}>
			)

	}
}

```


![MetadataViews.CollectionDisplay](/images/collectionDisplay.png "CollectionDisplay")

| Param      | Description |
| ----------- | ----------- |
| name   | Name of the NFT Collection        |
| description      | Human readable description of the NFT Collection      |
| externalURL      | The external url to the NFT Collection       |
| squareImage      | A square image that represent the NFT Collection    |
| bannerImage      | A 2 : 1 banner image that represent the NFT Collection  |
| socials      | Social links to your media       |

## Implementing `MetadataViews.Traits`

Trait views can add a lot more attributes to the NFT display on .Find. 
By returning trait views as recommended, you can fit the data in the places you want. 

```cadence

pub fun resolveView(_ type: Type): AnyStruct? {
	switch type {

		// Example for Traits
		case Type<MetadataViews.Traits>() : 

			let trait = MetadataViews.Trait(
				name: "Edition Stamp" ,      // Type<String>
				value: "Grand Architect",    // Type<AnyStruct>
				displayType: "String",       // Type<String?>
				rarity: MetadataViews.Rarity(// Type<MetadataViews.Rarity?>
					score: nil,              // Type<UFix64?>
					max: nil,                // Type<UFix64?>
					description: "Common"     // Type<String?>
				)
			)

			let dateTrait = MetadataViews.Trait(
				name: "BirthDay" ,      
				value: 1546360800.0,    		
				displayType: "Date",    
				rarity: nil             			// Not Needed
			)

			let numberTrait = MetadataViews.Trait(
				name: "Generation" ,      
				value: 1.0,    
				displayType: "Number",    
				rarity: MetadataViews.Rarity(
					score: nil,              		// Not Needed
					max: 2.0,                		// Optional
					description: nil    			// Optional
				)           
			)

			let boostTrait = MetadataViews.Trait(
				name: "Aqua Power" ,      
				value: 10.0,    
				displayType: "Boost",    
				rarity: MetadataViews.Rarity(		
					score: nil,              		// Not Needed
					max: 40.0,                		// Optional
					description: nil    			// Optional
				)           
			)

			let boostPercentageTrait = MetadataViews.Trait(
				name: "Stamina Increase" ,      
				value: 0.05,    
				displayType: "BoostPercentage",    
				rarity: MetadataViews.Rarity(		
					score: nil,              		// Not Needed
					max: nil,                		// Not Needed
					description: nil    			// Optional
				)           
			)

			let levelTrait = MetadataViews.Trait(
				name: "Stamina Increase" ,      
				value: 90.2,    
				displayType: "Level",    
				rarity: MetadataViews.Rarity(		
					score: nil,              		// Not Needed
					max: 90.2,                		// Optional
					description: nil    			// Optional
				)           
			)

			return MetadataViews.Traits(
				[
					trait, 
					dateTrait, 
					numberTrait, 
					boostTrait, 
					boostPercentageTrait, 
					levelTrait
				]
			)

	}
}

```

## String Trait
![MetadataViews.Traits](/images/traits_String.png "traits_String")


## Date Trait (Under development)
![MetadataViews.Traits](/images/traits_Date.png "traits_Date")

## Number Trait (Under development)
### Number
![MetadataViews.Traits](/images/traits_Number.png "traits_Number")

### Boost
![MetadataViews.Traits](/images/traits_Boost.png "traits_Boost")

### Boost Percentage
![MetadataViews.Traits](/images/traits_BoostPercentage.png "traits_BoostPercentage")

### Level
![MetadataViews.Traits](/images/traits_Level.png "traits_Level")

| Param      | Description |
| ----------- | ----------- |
| name   | Name of the trait  |
| value      | Value of the trait  |
| displayType      | Value of the trait, can be "String", "Number", "Date" etc. |
| rarity      | Additional rarity to this trait, description / numbder / maximum number of the rarity    |


## Implementing `MetadataViews.Medias`

Medias views can put all the precious media of the NFT on .Find. 
By returning medias views as recommended, all the media will be displayed to the viewers instead of just the main one.

```cadence

pub fun resolveView(_ type: Type): AnyStruct? {
	switch type {

		// Example for Medias 
		case Type<MetadataViews.Medias>() : 

			let IPFSMedia = MetadataViews.Media(
				file: 		MetadataViews.IPFSFile(
								cid: "Example_CID", 
								path: nil
							)
				mediaType: 	"image/example"
			)

			let IPFSMedia2 = MetadataViews.Media(
				file: 		MetadataViews.IPFSFile(
								cid: "Example_CID", 
								path: nil
							)
				mediaType: 	"image/example"
			)

			let HTTPMedia = MetadataViews.HTTPFile(
				url: 		"Example_HTTP_Link"
			)

			return MetadataViews.Medias(
				[
					IPFSMedia , 
					IPFSMedia2 , 
					HTTPMedia
				]
			)

	}
}

```

![MetadataViews.Medias](/images/medias.png "Medias")

Thumbnail of the NFT would be placed the first of the album. 
And followed by the sequence of MetadataViews.Medias exposed.

| Param      | Description |
| ----------- | ----------- |
| file   | Structs that implements MetadataViews.File Interface  |
| mediaType      | Abide by standard trees format. Reference : https://en.wikipedia.org/wiki/Media_type#Standards_tree, e.g. image/png, video/mp4  |