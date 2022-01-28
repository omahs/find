import Market from "../contracts/Market.cdc"
import FlowToken from "../contracts/standard/FlowToken.cdc"
import FUSD from "../contracts/standard/FUSD.cdc"
import NonFungibleToken from "../contracts/standard/NonFungibleToken.cdc"
import MetadataViews from "../contracts/standard/MetadataViews.cdc"
import Dandy from "../contracts/Dandy.cdc"
import TypedMetadata from "../contracts/TypedMetadata.cdc"

transaction(id: UInt64, directSellPrice:UFix64) {
	prepare(account: AuthAccount) {


		let saleItems= account.borrow<&Market.SaleItemCollection>(from: Market.SaleItemCollectionStoragePath)!
		let dandyPrivateCap=	account.getCapability<&Dandy.Collection{NonFungibleToken.Provider, MetadataViews.ResolverCollection}>(Dandy.CollectionPrivatePath)
		let pointer= TypedMetadata.AuthNFTPointer(cap: dandyPrivateCap, id: id)
		saleItems.listForSale(pointer: pointer, vaultType: Type<@FUSD.Vault>(), directSellPrice: directSellPrice)
	}
}