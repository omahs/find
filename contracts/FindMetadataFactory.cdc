import MetadataViews from "../contracts/standard/MetadataViews.cdc"
import NFTRegistry from "../contracts/NFTRegistry.cdc"
import FindViews from "../contracts/FindViews.cdc"

access(all) contract FindMetadataFactory {

	access(all) struct MetadataCollectionItem {
		access(all) let id:UInt64
		access(all) let uuid: UInt64 
		access(all) let name: String
		access(all) let image: String
		access(all) let collection: String
		// access(all) let source: String //which alchemy shard or our own Factory

		access(all) let rarity:String
		access(all) let subCollection: String? // <- This will be Alias unless they want something else

		access(all) let url: String
		access(all) let contentTypes:[String]
		access(all) let medias: [MetadataViews.Media]
		access(all) let tag: {String : String}
		access(all) let scalar: {String : UFix64}

		init(id:UInt64, type: Type, uuid: UInt64, name:String, image:String, url:String, contentTypes: [String], rarity: String, medias: [MetadataViews.Media], collection: String, subCollection: String?, tag: {String : String}, scalar: {String : UFix64}) {
			self.id=id
			self.uuid = uuid
			self.name=name
			self.url=url
			self.image=image
			self.contentTypes=contentTypes
			self.rarity=rarity
			self.medias=medias
			self.collection=collection
			self.tag=tag
			self.scalar=scalar
			self.subCollection=subCollection
		}
	}

	access(all) getNFTs(ownerAddress: Address, ids: {String:[UInt64]}): [MetadataCollectionItem] {
		let account= getAccount(ownerAddress)
		let items : [MetadataCollectionItem] = []


		for nftInfo in NFTRegistry.getNFTInfoAll().values {
			let resolverCollectionCap= account.getCapability<&{ViewResolver.ResolverCollection}>(nftInfo.publicPath)
			if resolverCollectionCap.check() {
				continue;
			}
			let collection = resolverCollectionCap.borrow()!
			for id in collection.getIDs() {
				let nft = collection.borrowViewResolver(id: id) 

				if let display= MetadataViews.getDisplay(nft) {
					var externalUrl=nftInfo.externalFixedUrl

					if let externalUrlViw=MetadataViews.getExternalURL(nft) { 
						externalUrl=externalUrlViw.url
					}

					var rarity=""
					if let r = FindViews.getRarity(nft) {
						rarity=r.rarityName
					}

					var tag : {String : String}={}
					if let t= FindViews.getTags(nft) {
						tag=t.getTag()
					}			

					var scalar : {String : UFix64}={}
					if let s= FindViews.getScalar(nft) {
						scalar=s.getScalar()
					}			

					var medias : [MetadataViews.Media] = []
					if let m= MetadataViews.getMedias(nft) {
						medias=m.items
					}	

					let cotentTypes : [String] = []
					for media in medias {
						cotentTypes.append(media.mediaType)
					}

					var subCollection : String? = nil 
					if let sc= MetadataViews.getNFTCollectionDisplay(nft) {
						subCollection=sc.name
					}

					let item = MetadataCollectionItem(
						id: id,
						type: nft.getType() ,
						uuid: nft.uuid ,
						name: display.name,
						image: display.thumbnail.uri(),
						url: externalUrl,
						contentTypes: cotentTypes,
						rarity: rarity,
						medias: medias,
						collection: nftInfo.alias,
						subCollection: subCollection,
						tag: tag,
						scalar: scalar
					)
					items.append(item)
				}
			}
		}
		return items
	}

	access(all) getNFTIDs(ownerAddress: Address): {String: [UInt64]} {
		let account= getAccount(ownerAddress)
		let registryData = NFTRegistry.getNFTInfoAll()

		let collections : {String:[UInt64]} ={}
		for item in registryData.values {
			let optCap = account.getCapability<&{ViewResolver.ResolverCollection}>(item.publicPath)
			if !optCap.check() {
				continue
			}
			let col=optCap!.borrow()!
			
			let ids=col.getIDs()
			let alias=item.alias
			if ids.length != 0 {
				collections[alias]=ids
			}
		}
		return collections
	}
}
