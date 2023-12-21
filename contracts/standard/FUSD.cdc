import FungibleToken from "./FungibleToken.cdc"
import ViewResolver from "./ViewResolver.cdc"
import MetadataViews from "./MetadataViews.cdc"
import FungibleTokenMetadataViews from "./FungibleTokenMetadataViews.cdc"

access(all) contract FUSD: ViewResolver {

    /// The event that is emitted when new tokens are minted
    access(all) event TokensMinted(amount: UFix64, type: String)

    // Event that is emitted when tokens are deposited to a Vault
    access(all) event TokensDeposited(amount: UFix64, to: Address?)

    // Event that is emitted when tokens are withdrawn from a Vault
    access(all) event TokensWithdrawn(amount: UFix64, from: Address?)




    /// Total supply of fusds in existence
    access(all) var totalSupply: UFix64

    /// Admin Path
    access(all) let AdminStoragePath: StoragePath

    /// User Paths
    access(all) let VaultStoragePath: StoragePath
    access(all) let VaultPublicPath: PublicPath
    access(all) let ReceiverPublicPath: PublicPath

    /// Function to return the types that the contract implements
    access(all) view fun getVaultTypes(): [Type] {
        let typeArray: [Type] = [Type<@FUSD.Vault>()]
        return typeArray
    }

    access(all) view fun getViews(): [Type] {
        let vaultRef = self.account.capabilities.borrow<&FUSD.Vault>(/public/fusdVault)
        ?? panic("Could not borrow a reference to the vault resolver")

        return vaultRef.getViews()
    }

    access(all) fun resolveView(_ view: Type): AnyStruct? {
        let vaultRef = self.account.capabilities.borrow<&FUSD.Vault>(/public/fusdVault)
        ?? panic("Could not borrow a reference to the vault resolver")

        return vaultRef.resolveView(view)
    }

    /// Vault
    ///
    /// Each user stores an instance of only the Vault in their storage
    /// The functions in the Vault and governed by the pre and post conditions
    /// in FungibleToken when they are called.
    /// The checks happen at runtime whenever a function is called.
    ///
    /// Resources can only be created in the context of the contract that they
    /// are defined in, so there is no way for a malicious user to create Vaults
    /// out of thin air. A special Minter resource needs to be defined to mint
    /// new tokens.
    ///
    access(all) resource Vault: FungibleToken.Vault {

        /// The total balance of this vault
        access(all) var balance: UFix64

        access(self) var storagePath: StoragePath
        access(self) var publicPath: PublicPath
        access(self) var receiverPath: PublicPath

        /// Returns the storage path where the vault should typically be stored
        access(all) view fun getDefaultStoragePath(): StoragePath? {
            return self.storagePath
        }

        /// Returns the public path where this vault should have a public capability
        access(all) view fun getDefaultPublicPath(): PublicPath? {
            return self.publicPath
        }

        /// Returns the public path where this vault's Receiver should have a public capability
        access(all) view fun getDefaultReceiverPath(): PublicPath? {
            return self.receiverPath
        }

        access(all) view fun getViews(): [Type] {
            return [
            Type<FungibleTokenMetadataViews.FTView>(),
            Type<FungibleTokenMetadataViews.FTDisplay>(),
            Type<FungibleTokenMetadataViews.FTVaultData>(),
            Type<FungibleTokenMetadataViews.TotalSupply>()
            ]
        }

        access(all) fun resolveView(_ view: Type): AnyStruct? {
            switch view {
            case Type<FungibleTokenMetadataViews.FTView>():
                return FungibleTokenMetadataViews.FTView(
                    ftDisplay: self.resolveView(Type<FungibleTokenMetadataViews.FTDisplay>()) as! FungibleTokenMetadataViews.FTDisplay?,
                    ftVaultData: self.resolveView(Type<FungibleTokenMetadataViews.FTVaultData>()) as! FungibleTokenMetadataViews.FTVaultData?
                )
            case Type<FungibleTokenMetadataViews.FTDisplay>():
                let media = MetadataViews.Media(
                    file: MetadataViews.HTTPFile(
                        url: "https://assets.website-files.com/5f6294c0c7a8cdd643b1c820/5f6294c0c7a8cda55cb1c936_Flow_Wordmark.svg"
                    ),
                    mediaType: "image/svg+xml"
                )
                let medias = MetadataViews.Medias([media])
                return FungibleTokenMetadataViews.FTDisplay(
                    name: "Example Fungible Token",
                    symbol: "EFT",
                    description: "This fungible token is used as an example to help you develop your next FT #onFlow.",
                    externalURL: MetadataViews.ExternalURL("https://example-ft.onflow.org"),
                    logos: medias,
                    socials: {
                        "twitter": MetadataViews.ExternalURL("https://twitter.com/flow_blockchain")
                    }
                )
            case Type<FungibleTokenMetadataViews.FTVaultData>():
                let vaultRef = FUSD.account.storage.borrow<&FUSD.Vault>(from: self.storagePath)
                ?? panic("Could not borrow a reference to the stored vault")
                return FungibleTokenMetadataViews.FTVaultData(
                    storagePath: self.storagePath,
                    receiverPath: self.receiverPath,
                    metadataPath: self.publicPath,
                    providerPath: /private/fusdVault,
                    receiverLinkedType: Type<&{FungibleToken.Receiver}>(),
                    metadataLinkedType: Type<&FUSD.Vault>(),
                    providerLinkedType: Type<&FUSD.Vault>(),
                    createEmptyVaultFunction: (fun(): @{FungibleToken.Vault} {
                        return <-vaultRef.createEmptyVault()
                    })
                )
            case Type<FungibleTokenMetadataViews.TotalSupply>():
                return FungibleTokenMetadataViews.TotalSupply(
                    totalSupply: FUSD.totalSupply
                )
            }
            return nil
        }

        /// getSupportedVaultTypes optionally returns a list of vault types that this receiver accepts
        access(all) view fun getSupportedVaultTypes(): {Type: Bool} {
            let supportedTypes: {Type: Bool} = {}
            supportedTypes[self.getType()] = true
            return supportedTypes
        }

        access(all) view fun isSupportedVaultType(type: Type): Bool {
            return self.getSupportedVaultTypes()[type] ?? false
        }

        // initialize the balance at resource creation time
        init(balance: UFix64) {
            self.balance = balance
            let identifier = "fusdVault"
            self.storagePath = StoragePath(identifier: identifier)!
            self.publicPath = PublicPath(identifier: identifier)!
            self.receiverPath = PublicPath(identifier: "fusdReceiver")!
        }

        /// Get the balance of the vault
        access(all) view fun getBalance(): UFix64 {
            return self.balance
        }

        /// withdraw
        ///
        /// Function that takes an amount as an argument
        /// and withdraws that amount from the Vault.
        ///
        /// It creates a new temporary Vault that is used to hold
        /// the tokens that are being transferred. It returns the newly
        /// created Vault to the context that called so it can be deposited
        /// elsewhere.
        ///
        access(FungibleToken.Withdrawable) fun withdraw(amount: UFix64): @FUSD.Vault {
            self.balance = self.balance - amount
            emit TokensWithdrawn(amount: amount, from: self.owner?.address)
            return <-create Vault(balance: amount)
        }

        /// deposit
        ///
        /// Function that takes a Vault object as an argument and adds
        /// its balance to the balance of the owners Vault.
        ///
        /// It is allowed to destroy the sent Vault because the Vault
        /// was a temporary holder of the tokens. The Vault's balance has
        /// been consumed and therefore can be destroyed.
        ///
        access(all) fun deposit(from: @{FungibleToken.Vault}) {
            let vault <- from as! @FUSD.Vault
            self.balance = self.balance + vault.balance
            emit TokensDeposited(amount: vault.balance, to: self.owner?.address)
            vault.balance = 0.0
            destroy vault
        }


        access(FungibleToken.Withdrawable) fun transfer(amount: UFix64, receiver: Capability<&{FungibleToken.Receiver}>) {
            let transferVault <- self.withdraw(amount: amount)

            // Get a reference to the recipient's Receiver
            let receiverRef = receiver.borrow()
            ?? panic("Could not borrow receiver reference to the recipient's Vault")

            // Deposit the withdrawn tokens in the recipient's receiver
            receiverRef.deposit(from: <-transferVault)
        }


        /// createEmptyVault
        ///
        /// Function that creates a new Vault with a balance of zero
        /// and returns it to the calling context. A user must call this function
        /// and store the returned Vault in their storage in order to allow their
        /// account to be able to receive deposits of this token type.
        ///
        access(all) fun createEmptyVault(): @FUSD.Vault {
            return <-create Vault(balance: 0.0)
        }
    }

    /// Minter
    ///
    /// Resource object that token admin accounts can hold to mint new tokens.
    ///
    access(all) resource Minter {
        /// mintTokens
        ///
        /// Function that mints new tokens, adds them to the total supply,
        /// and returns them to the calling context.
        ///
        access(all) fun mintTokens(amount: UFix64): @FUSD.Vault {
            FUSD.totalSupply = FUSD.totalSupply + amount
            emit TokensMinted(amount: amount, type: self.getType().identifier)
            return <-create Vault(balance: amount)
        }
    }

    /// createEmptyVault
    ///
    /// Function that creates a new Vault with a balance of zero
    /// and returns it to the calling context. A user must call this function
    /// and store the returned Vault in their storage in order to allow their
    /// account to be able to receive deposits of this token type.
    ///
    access(all) fun createEmptyVault(): @FUSD.Vault {
        return <- create Vault(balance: 0.0)
    }

    /// Function that destroys a Vault instance, effectively burning the tokens.
    ///
    /// @param from: The Vault resource containing the tokens to burn
    ///
    // TODO: Revisit if removal of custom destructors passes
    // Will need to add an update to total supply
    // See https://github.com/onflow/flips/pull/131
    access(all) fun burnTokens(from: @FUSD.Vault) {
        destroy from
    }

    init() {
        self.totalSupply = 1000.0

        self.AdminStoragePath = /storage/fusdAdmin 

        // Create the Vault with the total supply of tokens and save it in storage
        //
        let vault <- create Vault(balance: self.totalSupply)
        self.VaultStoragePath = vault.getDefaultStoragePath()!
        self.VaultPublicPath = vault.getDefaultPublicPath()!
        self.ReceiverPublicPath = vault.getDefaultReceiverPath()!

        self.account.storage.save(<-vault, to: self.VaultStoragePath)

        // Create a public capability to the stored Vault that exposes
        // the `deposit` method and getAcceptedTypes method through the `Receiver` interface
        // and the `getBalance()` method through the `Balance` interface
        //
        let fusdCap = self.account.capabilities.storage.issue<&Vault>(self.VaultStoragePath)
        self.account.capabilities.publish(fusdCap, at: self.VaultPublicPath)
        let receiverCap = self.account.capabilities.storage.issue<&{FungibleToken.Receiver}>(self.VaultStoragePath)
        self.account.capabilities.publish(receiverCap, at: self.ReceiverPublicPath)

        let capb = self.account.capabilities.storage.issue<&{FungibleToken.Vault}>(self.VaultStoragePath)
        self.account.capabilities.publish(capb, at: /public/fusdBalance)

        let admin <- create Minter()
        self.account.storage.save(<-admin, to: self.AdminStoragePath)
    }
}
