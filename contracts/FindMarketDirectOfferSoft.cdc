import FungibleToken from "./standard/FungibleToken.cdc"
import FlowToken from "./standard/FlowToken.cdc"
import NonFungibleToken from "./standard/NonFungibleToken.cdc"
import MetadataViews from "./standard/MetadataViews.cdc"
import FindViews from "../contracts/FindViews.cdc"
import Clock from "./Clock.cdc"
import Debug from "./Debug.cdc"
import FIND from "./FIND.cdc"
import FindMarket from "./FindMarket.cdc"
import Profile from "./Profile.cdc"

access(all) contract FindMarketDirectOfferSoft {

    access(all) event DirectOffer(tenant: String, id: UInt64, saleID: UInt64, seller: Address, sellerName: String?, amount: UFix64, status: String, vaultType:String, nft: FindMarket.NFTInfo?, buyer:Address?, buyerName:String?, buyerAvatar:String?, endsAt: UFix64?, previousBuyer:Address?, previousBuyerName:String?)

    access(all) resource SaleItem : FindMarket.SaleItem{

        access(contract) var pointer: {FindViews.Pointer}
        access(contract) var offerCallback: Capability<&MarketBidCollection>

        access(contract) var directOfferAccepted:Bool
        access(contract) var validUntil: UFix64?
        access(contract) var saleItemExtraField: {String : AnyStruct}
        access(contract) let totalRoyalties: UFix64

        init(pointer: {FindViews.Pointer}, callback: Capability<&MarketBidCollection>, validUntil: UFix64?, saleItemExtraField: {String : AnyStruct}) {
            self.pointer=pointer
            self.offerCallback=callback
            self.directOfferAccepted=false
            self.validUntil=validUntil
            self.saleItemExtraField=saleItemExtraField
            self.totalRoyalties=self.pointer.getTotalRoyaltiesCut()
        }


        access(all) fun getId() : UInt64{
            return self.pointer.getUUID()
        }

        access(all) fun acceptDirectOffer() {
            self.directOfferAccepted=true
        }

        //Here we do not get a vault back, it is sent in to the method itself
        access(all) fun acceptNonEscrowedBid() {
            if !self.offerCallback.check() {
                panic("Bidder unlinked the bid collection capability. Bidder Address : ".concat(self.offerCallback.address.toString()))
            }
            let pointer= self.pointer as! FindViews.AuthNFTPointer
            self.offerCallback.borrow()!.acceptNonEscrowed(<- pointer.withdraw())
        }

        access(all) fun getRoyalty() : MetadataViews.Royalties {
            return self.pointer.getRoyalty()
        }

        access(all) fun getFtType() : Type {
            if !self.offerCallback.check() {
                panic("Bidder unlinked the bid collection capability. Bidder Address : ".concat(self.offerCallback.address.toString()))
            }
            return self.offerCallback.borrow()!.getVaultType(self.getId())
        }

        access(all) fun getItemID() : UInt64 {
            return self.pointer.id
        }

        access(all) fun getItemType() : Type {
            return self.pointer.getItemType()
        }

        access(all) fun getAuction(): FindMarket.AuctionItem? {
            return nil
        }

        access(all) fun getSaleType() : String {
            if self.directOfferAccepted {
                return "active_finished"
            }
            return "active_ongoing"
        }

        access(all) fun getListingType() : Type {
            return Type<@SaleItem>()
        }

        access(all) fun getListingTypeIdentifier() : String {
            return Type<@SaleItem>().identifier
        }

        access(all) fun getBalance() : UFix64 {
            if !self.offerCallback.check() {
                panic("Bidder unlinked the bid collection capability. Bidder Address : ".concat(self.offerCallback.address.toString()))
            }
            return self.offerCallback.borrow()!.getBalance(self.getId())
        }

        access(all) fun getSeller() : Address {
            return self.pointer.owner()
        }

        access(all) fun getSellerName() : String? {
            let address = self.pointer.owner()
            return FIND.reverseLookup(address)
        }

        access(all) fun getBuyer() : Address? {
            return self.offerCallback.address
        }

        access(all) fun getBuyerName() : String? {
            if let name = FIND.reverseLookup(self.offerCallback.address) {
                return name
            }
            return nil
        }

        access(all) fun toNFTInfo(_ detail: Bool) : FindMarket.NFTInfo{
            return FindMarket.NFTInfo(self.pointer.getViewResolver(), id: self.pointer.id, detail:detail)
        }

        access(all) fun setValidUntil(_ time: UFix64?) {
            self.validUntil=time
        }

        access(all) fun getValidUntil() : UFix64? {
            return self.validUntil
        }

        access(all) fun setPointer(_ pointer: FindViews.AuthNFTPointer) {
            self.pointer=pointer
        }

        access(all) fun setCallback(_ callback: Capability<&MarketBidCollection>) {
            self.offerCallback=callback
        }

        access(all) fun checkPointer() : Bool {
            return self.pointer.valid()
        }

        access(all) fun checkSoulBound() : Bool {
            return self.pointer.checkSoulBound()
        }

        access(all) fun getSaleItemExtraField() : {String : AnyStruct} {
            return self.saleItemExtraField
        }

        access(contract) fun setSaleItemExtraField(_ field: {String : AnyStruct}) {
            self.saleItemExtraField = field
        }

        access(all) fun getTotalRoyalties() : UFix64 {
            return self.totalRoyalties
        }

        access(all) fun validateRoyalties() : Bool {
            return self.totalRoyalties == self.pointer.getTotalRoyaltiesCut()
        }

        access(all) fun getDisplay() : MetadataViews.Display {
            return self.pointer.getDisplay()
        }

        access(all) fun getNFTCollectionData() : MetadataViews.NFTCollectionData {
            return self.pointer.getNFTCollectionData()
        }
    }

    access(all) resource interface SaleItemCollectionPublic {
        //fetch all the tokens in the collection
        access(all) fun getIds(): [UInt64]
        access(all) fun containsId(_ id: UInt64): Bool
        access(contract) fun cancelBid(_ id: UInt64)
        access(contract) fun registerIncreasedBid(_ id: UInt64)

        //place a bid on a token
        access(contract) fun registerBid(item: FindViews.ViewReadPointer, callback: Capability<&MarketBidCollection>, validUntil: UFix64?, saleItemExtraField: {String : AnyStruct})

        access(contract) fun isAcceptedDirectOffer(_ id:UInt64) : Bool

        access(contract) fun fulfillDirectOfferNonEscrowed(id:UInt64, vault: @{FungibleToken.Vault})

    }

    access(all) resource SaleItemCollection: SaleItemCollectionPublic, FindMarket.SaleItemCollectionPublic {
        //is this the best approach now or just put the NFT inside the saleItem?
        access(contract) var items: @{UInt64: SaleItem}

        access(contract) let tenantCapability: Capability<&{FindMarket.TenantPublic}>

        init (_ tenantCapability: Capability<&{FindMarket.TenantPublic}>) {
            self.items <- {}
            self.tenantCapability=tenantCapability
        }

        access(self) fun getTenant() : &{FindMarket.TenantPublic} {
            if !self.tenantCapability.check() {
                panic("Tenant client is not linked anymore")
            }
            return self.tenantCapability.borrow()!
        }

        access(all) fun isAcceptedDirectOffer(_ id:UInt64) : Bool{

            if !self.items.containsKey(id) {
                panic("Invalid id=".concat(id.toString()))
            }
            let saleItem = self.borrow(id)

            return saleItem.directOfferAccepted
        }

        access(all) fun getListingType() : Type {
            return Type<@SaleItem>()
        }

        //this is called when a buyer cancel a direct offer
        access(contract) fun cancelBid(_ id: UInt64) {
            if !self.items.containsKey(id) {
                panic("Invalid id=".concat(id.toString()))
            }
            let saleItem=self.borrow(id)

            let tenant=self.getTenant()
            let ftType= saleItem.getFtType()

            let status="cancel"
            let balance=saleItem.getBalance()
            let buyer=saleItem.getBuyer()!
            let buyerName=FIND.reverseLookup(buyer)
            let profile = Profile.find(buyer)

            var nftInfo:FindMarket.NFTInfo?=nil
            if saleItem.checkPointer() {
                nftInfo=saleItem.toNFTInfo(false)
            }

            emit DirectOffer(tenant:tenant.name, id: saleItem.getId(), saleID: saleItem.uuid, seller:self.owner!.address, sellerName: FIND.reverseLookup(self.owner!.address), amount: balance, status:status, vaultType: ftType.identifier, nft:nftInfo, buyer: buyer, buyerName: buyerName, buyerAvatar: profile.getAvatar(), endsAt: saleItem.validUntil, previousBuyer:nil, previousBuyerName:nil)


            destroy <- self.items.remove(key: id)
        }

        //The only thing we do here is basically register an event
        access(contract) fun registerIncreasedBid(_ id: UInt64) {

            if !self.items.containsKey(id) {
                panic("Invalid id=".concat(id.toString()))
            }
            let saleItem=self.borrow(id)

            let tenant=self.getTenant()
            let nftType=saleItem.getItemType()
            let ftType= saleItem.getFtType()

            let actionResult=tenant.allowedAction(listingType: Type<@FindMarketDirectOfferSoft.SaleItem>(), nftType: nftType, ftType: ftType, action: FindMarket.MarketAction(listing:true, name: "increase bid in direct offer soft"), seller: self.owner!.address, buyer: saleItem.offerCallback.address)

            if !actionResult.allowed {
                panic(actionResult.message)
            }

            let status="active_offered"
            let owner=self.owner!.address
            let balance=saleItem.getBalance()
            let buyer=saleItem.getBuyer()!
            let buyerName=FIND.reverseLookup(buyer)
            let profile = Profile.find(buyer)

            let nftInfo=saleItem.toNFTInfo(true)

            emit DirectOffer(tenant:tenant.name, id: id, saleID: saleItem.uuid, seller:owner, sellerName: FIND.reverseLookup(owner), amount: balance, status:status, vaultType: ftType.identifier, nft:nftInfo, buyer: buyer, buyerName: buyerName, buyerAvatar: profile.getAvatar(), endsAt: saleItem.validUntil, previousBuyer:nil, previousBuyerName:nil)

        }


        //This is a function that buyer will call (via his bid collection) to register the bicCallback with the seller
        access(contract) fun registerBid(item: FindViews.ViewReadPointer, callback: Capability<&MarketBidCollection>, validUntil: UFix64?, saleItemExtraField: {String : AnyStruct}) {

            let id = item.getUUID()

            //If there are no bids from anybody else before we need to make the item
            if !self.items.containsKey(id) {
                let saleItem <- create SaleItem(pointer: item, callback: callback, validUntil: validUntil, saleItemExtraField: saleItemExtraField)

                let tenant=self.getTenant()
                let nftType= saleItem.getItemType()
                let ftType= saleItem.getFtType()

                let actionResult=tenant.allowedAction(listingType: Type<@FindMarketDirectOfferSoft.SaleItem>(), nftType: saleItem.getItemType(), ftType: saleItem.getFtType(), action: FindMarket.MarketAction(listing:true, name: "bid in direct offer soft"), seller: self.owner!.address, buyer: callback.address)

                if !actionResult.allowed {
                    panic(actionResult.message)
                }
                self.items[id] <-! saleItem
                let saleItemRef=self.borrow(id)
                let status="active_offered"
                let owner=self.owner!.address
                let balance=saleItemRef.getBalance()
                let buyer=callback.address
                let buyerName=FIND.reverseLookup(buyer)
                let profile = Profile.find(buyer)

                let nftInfo=saleItemRef.toNFTInfo(true)

                emit DirectOffer(tenant:tenant.name, id: id, saleID: saleItemRef.uuid, seller:owner, sellerName: FIND.reverseLookup(owner), amount: balance, status:status, vaultType: ftType.identifier, nft:nftInfo, buyer: buyer, buyerName: buyerName, buyerAvatar: profile.getAvatar(), endsAt: saleItemRef.validUntil, previousBuyer:nil, previousBuyerName:nil)


                return
            }


            let saleItem=self.borrow(id)
            if self.borrow(id).getBuyer()! == callback.address {
                panic("You already have the latest bid on this item, use the incraseBid transaction")
            }

            let tenant=self.getTenant()
            let nftType= saleItem.getItemType()
            let ftType= saleItem.getFtType()

            let actionResult=tenant.allowedAction(listingType: Type<@FindMarketDirectOfferSoft.SaleItem>(), nftType: nftType, ftType: ftType, action: FindMarket.MarketAction(listing:true, name: "bid in direct offer soft"), seller: self.owner!.address, buyer: callback.address)

            if !actionResult.allowed {
                panic(actionResult.message)
            }

            let balance=callback.borrow()?.getBalance(id) ?? panic("Bidder unlinked the bid collection capability. bidder address : ".concat(callback.address.toString()))

            let currentBalance=saleItem.getBalance()
            Debug.log("currentBalance=".concat(currentBalance.toString()).concat(" new bid is at=").concat(balance.toString()))
            if currentBalance >= balance {
                panic("There is already a higher bid on this item. Current bid : ".concat(currentBalance.toString()).concat(" . New bid is at : ").concat(balance.toString()))
            }
            let previousBuyer=saleItem.offerCallback.address
            //somebody else has the highest item so we cancel it
            saleItem.offerCallback.borrow()!.cancelBidFromSaleItem(id)
            saleItem.setValidUntil(validUntil)
            saleItem.setSaleItemExtraField(saleItemExtraField)
            saleItem.setCallback(callback)

            let status="active_offered"
            let owner=self.owner!.address
            let buyer=saleItem.getBuyer()!
            let buyerName=FIND.reverseLookup(buyer)
            let profile = Profile.find(buyer)

            let nftInfo=saleItem.toNFTInfo(true)

            let previousBuyerName = FIND.reverseLookup(previousBuyer)


            emit DirectOffer(tenant:tenant.name, id: id, saleID: saleItem.uuid, seller:owner, sellerName: FIND.reverseLookup(owner), amount: balance, status:status, vaultType: ftType.identifier, nft:nftInfo, buyer: buyer, buyerName: buyerName, buyerAvatar: profile.getAvatar(), endsAt: saleItem.validUntil, previousBuyer:previousBuyer, previousBuyerName:previousBuyerName)


        }


        //cancel will reject a direct offer
        access(all) fun cancel(_ id: UInt64) {

            if !self.items.containsKey(id) {
                panic("Invalid id=".concat(id.toString()))
            }

            let saleItem=self.borrow(id)

            let tenant=self.getTenant()
            let ftType= saleItem.getFtType()


            var status = "cancel_rejected"
            let owner=self.owner!.address
            let balance=saleItem.getBalance()
            let buyer=saleItem.getBuyer()!
            let buyerName=FIND.reverseLookup(buyer)
            let profile = Profile.find(buyer)

            var nftInfo:FindMarket.NFTInfo?=nil
            if saleItem.checkPointer() {
                nftInfo=saleItem.toNFTInfo(false)
            }

            emit DirectOffer(tenant:tenant.name, id: id, saleID: saleItem.uuid, seller:owner, sellerName: FIND.reverseLookup(owner), amount: balance, status:status, vaultType: ftType.identifier, nft:nftInfo, buyer: buyer, buyerName: buyerName, buyerAvatar: profile.getAvatar(), endsAt: saleItem.validUntil, previousBuyer:nil, previousBuyerName:nil)

            if !saleItem.offerCallback.check() {
                panic("Seller unlinked the SaleItem collection capability. seller address : ".concat(saleItem.offerCallback.address.toString()))
            }
            saleItem.offerCallback.borrow()!.cancelBidFromSaleItem(id)
            destroy <- self.items.remove(key: id)
        }

        access(all) fun acceptOffer(_ pointer: FindViews.AuthNFTPointer) {

            let id = pointer.getUUID()

            if !self.items.containsKey(id) {
                panic("Invalid id=".concat(id.toString()))
            }

            let saleItem = self.borrow(id)

            if saleItem.validUntil != nil && saleItem.validUntil! < Clock.time() {
                panic("This direct offer is already expired")
            }

            let tenant=self.getTenant()
            let nftType= saleItem.getItemType()
            let ftType= saleItem.getFtType()

            let actionResult=tenant.allowedAction(listingType: Type<@FindMarketDirectOfferSoft.SaleItem>(), nftType: nftType, ftType: ftType, action: FindMarket.MarketAction(listing:false, name: "accept offer in direct offer soft"), seller: self.owner!.address, buyer: saleItem.offerCallback.address)

            if !actionResult.allowed {
                panic(actionResult.message)
            }

            //Set the auth pointer in the saleItem so that it now can be fulfilled
            saleItem.setPointer(pointer)
            saleItem.acceptDirectOffer()

            let status="active_accepted"
            let owner=self.owner!.address
            let balance=saleItem.getBalance()
            let buyer=saleItem.getBuyer()!
            let buyerName=FIND.reverseLookup(buyer)
            let profile = Profile.find(buyer)

            let nftInfo=saleItem.toNFTInfo(true)

            emit DirectOffer(tenant:tenant.name, id: id, saleID: saleItem.uuid, seller:owner, sellerName: FIND.reverseLookup(owner), amount: balance, status:status, vaultType: ftType.identifier, nft:nftInfo, buyer: buyer, buyerName: buyerName, buyerAvatar: profile.getAvatar(), endsAt: saleItem.validUntil, previousBuyer:nil, previousBuyerName:nil)


        }

        /// this is called from a bid when a seller accepts
        access(contract) fun fulfillDirectOfferNonEscrowed(id:UInt64, vault: @{FungibleToken.Vault}) {

            if !self.items.containsKey(id) {
                panic("Invalid id=".concat(id.toString()))
            }

            let saleItem = self.borrow(id)
            if !saleItem.directOfferAccepted {
                panic("cannot fulfill a direct offer that is not accepted yet")
            }

            if vault.getType() != saleItem.getFtType() {
                panic("The FT vault sent in to fulfill does not match the required type. Required Type : ".concat(saleItem.getFtType().identifier).concat(" . Sent-in vault type : ".concat(vault.getType().identifier)))
            }

            let tenant=self.getTenant()
            let nftType= saleItem.getItemType()
            let ftType= saleItem.getFtType()

            let actionResult=tenant.allowedAction(listingType: Type<@FindMarketDirectOfferSoft.SaleItem>(), nftType: nftType, ftType: ftType, action: FindMarket.MarketAction(listing:false, name: "fulfill directOffer"), seller: self.owner!.address, buyer: saleItem.offerCallback.address)

            if !actionResult.allowed {
                panic(actionResult.message)
            }

            let cuts= tenant.getCuts(name: actionResult.name, listingType: Type<@FindMarketDirectOfferSoft.SaleItem>(), nftType: nftType, ftType: ftType)


            let status="sold"
            let owner=self.owner!.address
            let balance=saleItem.getBalance()
            let buyer=saleItem.getBuyer()!
            let buyerName=FIND.reverseLookup(buyer)
            let sellerName=FIND.reverseLookup(owner)
            let profile = Profile.find(buyer)

            let nftInfo=saleItem.toNFTInfo(true)

            emit DirectOffer(tenant:tenant.name, id: saleItem.getId(), saleID: saleItem.uuid, seller:owner, sellerName: sellerName, amount: balance, status:status, vaultType: ftType.identifier, nft:nftInfo, buyer: buyer, buyerName: buyerName, buyerAvatar: profile.getAvatar(), endsAt: saleItem.validUntil, previousBuyer:nil, previousBuyerName:nil)

            let royalty=saleItem.getRoyalty()
            saleItem.acceptNonEscrowedBid()

            let resolved : {Address : String} = {}
            resolved[buyer] = buyerName ?? ""
            resolved[owner] = sellerName ?? ""
            resolved[FindMarketDirectOfferSoft.account.address] =  "find"
            // Have to make sure the tenant always have the valid find name
            resolved[FindMarket.tenantNameAddress[tenant.name]!] =  tenant.name

            FindMarket.pay(tenant: tenant.name, id:id, saleItem: saleItem, vault: <- vault, royalty:royalty, nftInfo: nftInfo, cuts:cuts, resolver: fun(address:Address): String? { return FIND.reverseLookup(address) }, resolvedAddress: resolved)

            destroy <- self.items.remove(key: id)
        }

        access(all) fun getIds(): [UInt64] {
            return self.items.keys
        }

        access(all) fun getRoyaltyChangedIds(): [UInt64] {
            let ids : [UInt64] = []
            for id in self.getIds() {
                let item = self.borrow(id)
                if !item.validateRoyalties() {
                    ids.append(id)
                }
            }
            return ids
        }

        access(all) fun containsId(_ id: UInt64): Bool {
            return self.items.containsKey(id)
        }

        access(all) fun borrow(_ id: UInt64): &SaleItem {
            if !self.items.containsKey(id) {
                panic("This id does not exist.".concat(id.toString()))
            }
            return (&self.items[id] as &SaleItem?)!
        }

        access(all) fun borrowSaleItem(_ id: UInt64) : &{FindMarket.SaleItem} {
            if !self.items.containsKey(id) {
                panic("This id does not exist.".concat(id.toString()))
            }
            return (&self.items[id] as &{FindMarket.SaleItem}?)!
        }
    }

    /*
    ==========================================================================
    Bids are a collection/resource for storing the bids bidder made on leases
    ==========================================================================
    */

    access(all) resource Bid : FindMarket.Bid {
        access(contract) let from: Capability<&{SaleItemCollectionPublic}>
        access(contract) let nftCap: Capability<&{NonFungibleToken.Receiver}>
        access(contract) let itemUUID: UInt64

        //this should reflect on what the above uuid is for
        access(contract) let vaultType: Type
        access(contract) var bidAt: UFix64
        access(contract) var balance: UFix64 //This is what you bid for non escrowed bids
        access(contract) let bidExtraField: {String : AnyStruct}

        init(from: Capability<&{SaleItemCollectionPublic}>, itemUUID: UInt64, nftCap: Capability<&{NonFungibleToken.Receiver}>, vaultType:Type,  nonEscrowedBalance:UFix64, bidExtraField: {String : AnyStruct}){
            self.vaultType= vaultType
            self.balance=nonEscrowedBalance
            self.itemUUID=itemUUID
            self.from=from
            self.bidAt=Clock.time()
            self.nftCap=nftCap
            self.bidExtraField=bidExtraField
        }

        access(contract) fun setBidAt(_ time: UFix64) {
            self.bidAt=time
        }

        access(contract) fun increaseBid(_ amount:UFix64) {
            self.balance=self.balance+amount
        }

        access(all) fun getBalance() : UFix64 {
            return self.balance
        }

        access(all) fun getSellerAddress() : Address {
            return self.from.address
        }

        access(all) fun getBidExtraField() : {String : AnyStruct} {
            return self.bidExtraField
        }
    }

    access(all) resource interface MarketBidCollectionPublic {
        access(all) fun getBalance(_ id: UInt64) : UFix64
        access(all) fun getVaultType(_ id: UInt64) : Type
        access(all) fun containsId(_ id: UInt64): Bool
        access(contract) fun acceptNonEscrowed(_ nft: @{NonFungibleToken.NFT})
        access(contract) fun cancelBidFromSaleItem(_ id: UInt64)
    }

    //A collection stored for bidders/buyers
    access(all) resource MarketBidCollection: MarketBidCollectionPublic, FindMarket.MarketBidCollectionPublic {

        access(contract) var bids : @{UInt64: Bid}
        access(contract) let receiver: Capability<&{FungibleToken.Receiver}>
        access(contract) let tenantCapability: Capability<&{FindMarket.TenantPublic}>

        //not sure we can store this here anymore. think it needs to be in every bid
        init(receiver: Capability<&{FungibleToken.Receiver}>, tenantCapability: Capability<&{FindMarket.TenantPublic}>) {
            self.bids <- {}
            self.receiver=receiver
            self.tenantCapability=tenantCapability
        }

        access(self) fun getTenant() : &{FindMarket.TenantPublic} {
            if !self.tenantCapability.check() {
                panic("Tenant client is not linked anymore")
            }
            return self.tenantCapability.borrow()!
        }

        //called from lease when auction is ended
        access(contract) fun acceptNonEscrowed(_ nft: @{NonFungibleToken.NFT}) {
            let id= nft.getID()
            let bid <- self.bids.remove(key: nft.uuid) ?? panic("missing bid")
            if !bid.nftCap.check() {
                panic("Bidder unlinked the nft receiver capability. bidder address : ".concat(bid.nftCap.address.toString()))
            }
            bid.nftCap.borrow()!.deposit(token: <- nft)
            destroy bid
        }

        access(all) fun getVaultType(_ id:UInt64) : Type {
            return self.borrowBid(id).vaultType
        }

        access(all) fun getIds() : [UInt64] {
            return self.bids.keys
        }

        access(all) fun containsId(_ id: UInt64) : Bool {
            return self.bids.containsKey(id)
        }

        access(all) fun getBidType() : Type {
            return Type<@Bid>()
        }


        access(all) fun bid(item: FindViews.ViewReadPointer, amount: UFix64, vaultType:Type, nftCap: Capability<&{NonFungibleToken.Receiver}>, validUntil: UFix64?, saleItemExtraField: {String : AnyStruct}, bidExtraField: {String : AnyStruct}) {

            // ensure it is not a 0 dollar listing
            if amount <= 0.0 {
                panic("Offer price should be greater than 0")
            }

            // ensure validUntil is valid
            if validUntil != nil && validUntil! < Clock.time() {
                panic("Valid until is before current time")
            }

            // check soul bound
            if item.checkSoulBound() {
                panic("This item is soul bounded and cannot be traded")
            }

            if self.owner!.address == item.owner() {
                panic("You cannot bid on your own resource")
            }

            let uuid=item.getUUID()

            if self.bids[uuid] != nil {
                panic("You already have an bid for this item, use increaseBid on that bid")
            }
            let tenant=self.getTenant()

            // Check if it is onefootball. If so, listing has to be at least $0.65 (DUC)
            if tenant.name == "onefootball" {
                // ensure it is not a 0 dollar listing
                if amount <= 0.65 {
                    panic("Offer price should be greater than 0.65")
                }
            }

            let from=getAccount(item.owner()).capabilities.get<&SaleItemCollection>(tenant.getPublicPath(Type<@SaleItemCollection>()))!

            let bid <- create Bid(from: from, itemUUID:uuid, nftCap: nftCap, vaultType: vaultType, nonEscrowedBalance:amount, bidExtraField: bidExtraField)
            let saleItemCollection= from.borrow() ?? panic("Could not borrow sale item for id=".concat(uuid.toString()))
            let callbackCapability =self.owner!.capabilities.get<&MarketBidCollection>(tenant.getPublicPath(Type<@MarketBidCollection>()))!

            let oldToken <- self.bids[uuid] <- bid
            saleItemCollection.registerBid(item: item, callback: callbackCapability, validUntil: validUntil, saleItemExtraField: saleItemExtraField)
            destroy oldToken
        }

        access(all) fun fulfillDirectOffer(id:UInt64, vault: @{FungibleToken.Vault}) {

            if self.bids[id] == nil {
                panic( "You need to have a bid here already".concat(id.toString()))
            }

            let bid =self.borrowBid(id)
            let saleItem=bid.from.borrow()!

            if !saleItem.isAcceptedDirectOffer(id) {
                panic("offer is not accepted yet")
            }

            saleItem.fulfillDirectOfferNonEscrowed(id:id, vault: <- vault)
        }

        access(all) fun increaseBid(id: UInt64, increaseBy: UFix64) {
            let bid =self.borrowBid(id)
            bid.setBidAt(Clock.time())
            bid.increaseBid(increaseBy)
            if !bid.from.check() {
                panic("Seller unlinked the SaleItem collection capability. seller address : ".concat(bid.from.address.toString()))
            }
            bid.from.borrow()!.registerIncreasedBid(id)
        }

        /// The users cancel a bid himself
        access(all) fun cancelBid(_ id: UInt64) {
            let bid= self.borrowBid(id)
            if !bid.from.check() {
                panic("Seller unlinked the SaleItem collection capability. seller address : ".concat(bid.from.address.toString()))
            }
            bid.from.borrow()!.cancelBid(id)
            self.cancelBidFromSaleItem(id)
        }

        //called from saleItem when things are cancelled
        //if the bid is canceled from seller then we move the vault tokens back into your vault
        access(contract) fun cancelBidFromSaleItem(_ id: UInt64) {
            let bid <- self.bids.remove(key: id) ?? panic("missing bid")
            destroy bid
        }

        access(all) fun borrowBid(_ id: UInt64): &Bid {
            if !self.bids.containsKey(id) {
                panic("This id does not exist.".concat(id.toString()))
            }
            return (&self.bids[id])!
        }

        access(all) fun borrowBidItem(_ id: UInt64): &{FindMarket.Bid} {
            if !self.bids.containsKey(id) {
                panic("This id does not exist.".concat(id.toString()))
            }
            return (&self.bids[id] as &{FindMarket.Bid}?)!
        }

        access(all) fun getBalance(_ id: UInt64) : UFix64 {
            let bid= self.borrowBid(id)
            return bid.balance
        }

    }

    //Create an empty lease collection that store your leases to a name
     access(all) fun createEmptySaleItemCollection(_ tenantCapability: Capability<&{FindMarket.TenantPublic}>) : @SaleItemCollection {
        return <- create SaleItemCollection(tenantCapability)
    }

    access(all) fun createEmptyMarketBidCollection(receiver: Capability<&{FungibleToken.Receiver}>, tenantCapability: Capability<&{FindMarket.TenantPublic}>) : @MarketBidCollection {
        return <- create MarketBidCollection(receiver: receiver, tenantCapability:tenantCapability)
    }

    access(all) fun getSaleItemCapability(marketplace:Address, user:Address) : Capability<&SaleItemCollection>? {
        if FindMarket.getTenantCapability(marketplace) == nil {
            panic("Invalid tenant")
        }
        if let tenant=FindMarket.getTenantCapability(marketplace)!.borrow() {
            return getAccount(user).capabilities.get<&SaleItemCollection>(tenant.getPublicPath(Type<@SaleItemCollection>()))
        }
        return nil
    }

    access(all) fun getBidCapability( marketplace:Address, user:Address) : Capability<&MarketBidCollection>? {
        if FindMarket.getTenantCapability(marketplace) == nil {
            panic("Invalid tenant")
        }
        if let tenant=FindMarket.getTenantCapability(marketplace)!.borrow() {
            return getAccount(user).capabilities.get<&MarketBidCollection>(tenant.getPublicPath(Type<@MarketBidCollection>()))
        }
        return nil
    }

    init() {
        // TODO:
        // FindMarket.addSaleItemType(Type<@SaleItem>())
        // FindMarket.addSaleItemCollectionType(Type<@SaleItemCollection>())
        // FindMarket.addMarketBidType(Type<@Bid>())
        // FindMarket.addMarketBidCollectionType(Type<@MarketBidCollection>())
    }
}
