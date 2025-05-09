# GameItems Smart Contract

A Stacks blockchain smart contract for managing in-game items as NFTs with extended gaming functionality.

## Overview

This smart contract implements a SIP-009 compliant NFT system specifically designed for gaming applications. It provides a comprehensive solution for creating, managing, trading, and upgrading in-game items on the Stacks blockchain.

## Features

- **NFT Compliance**: Fully compliant with the SIP-009 NFT standard
- **Item Creation**: Create new item types with detailed metadata
- **Item Minting**: Mint multiple copies of existing items
- **Item Transfer**: Transfer items between users
- **Marketplace**: Built-in marketplace for buying and selling items
- **Upgrading System**: Combine items to create new, upgraded items
- **Creator Whitelist**: Manage who can create new items
- **Metadata Management**: Update item metadata as needed
- **Batch Operations**: Perform multiple transfers in a single transaction
- **Burn Mechanism**: Remove items from circulation

## Contract Functions

### Administration

- `set-contract-owner`: Change the contract owner
- `set-admin-fee`: Set the marketplace fee (in basis points)
- `add-to-whitelist`: Add a creator to the whitelist
- `remove-from-whitelist`: Remove a creator from the whitelist

### Item Management

- `create-item`: Create a new item type with metadata
- `mint`: Create copies of an existing item
- `transfer-item`: Transfer items between users
- `burn`: Destroy items
- `update-item-metadata`: Update an item's metadata
- `set-tradeable`: Enable or disable trading for an item

### Marketplace

- `create-listing`: List items for sale
- `cancel-listing`: Cancel an active listing
- `buy-item`: Purchase items from a listing

### Item Upgrading

- `add-upgrade`: Define an item upgrade recipe
- `upgrade-item`: Upgrade an item using a defined recipe
- `set-upgrade-enabled`: Enable or disable an upgrade recipe

### Read-Only Functions

- `get-item-details`: Get details about an item
- `get-item-balance`: Check a user's balance of a specific item
- `get-listing`: Get details about a marketplace listing
- `is-listing-active`: Check if a listing is active
- `is-user-listing`: Check if a listing belongs to a user
- `is-whitelisted`: Check if a creator is whitelisted

## Data Structures

### Item

Each item contains the following information:
- `name`: Item name
- `description`: Item description
- `image-uri`: URI to the item's image
- `creator`: The creator's principal
- `item-type`: The type of item (e.g., weapon, armor)
- `attributes`: List of traits and values
- `metadata`: Optional additional metadata
- `created-at`: Block height when created
- `rarity`: Rarity level
- `tradeable`: Whether the item can be traded

### Marketplace Listing

- `item-id`: The ID of the item being sold
- `seller`: The seller's principal
- `price`: The price in STX
- `expiry`: Block height when the listing expires
- `quantity`: Number of items for sale
- `active`: Whether the listing is active

### Upgrade Recipe

- `base-item-id`: The item to be upgraded
- `required-items`: List of items required for the upgrade
- `result-item-id`: The item produced by the upgrade
- `enabled`: Whether the upgrade is enabled

## Error Codes

- `ERR-NOT-AUTHORIZED (u100)`: Not authorized to perform the action
- `ERR-ITEM-EXISTS (u101)`: Item already exists
- `ERR-ITEM-NOT-FOUND (u102)`: Item not found
- `ERR-INSUFFICIENT-BALANCE (u103)`: Insufficient item balance
- `ERR-TRANSFER-FAILED (u104)`: Transfer failed
- `ERR-LISTING-NOT-FOUND (u105)`: Listing not found
- `ERR-LISTING-EXPIRED (u106)`: Listing has expired
- `ERR-INVALID-PRICE (u107)`: Invalid price
- `ERR-SELF-TRANSFER (u108)`: Cannot transfer to yourself

## Usage Examples

### Creating a New Item

```clarity
(contract-call? .game-items create-item 
  "Excalibur" 
  "A legendary sword of immense power" 
  "https://example.com/items/excalibur.png" 
  "weapon" 
  (list 
    {trait-type: "damage", value: "100"} 
    {trait-type: "element", value: "light"}
  )
  (some "{\"lore\":\"Sword of King Arthur\"}")
  u5  ;; rarity
  true ;; tradeable
)
```

### Minting Items

```clarity
(contract-call? .game-items mint u1 u10 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Creating a Marketplace Listing

```clarity
(contract-call? .game-items create-listing u1 u1000000 u1 u100000)
```

### Purchasing an Item

```clarity
(contract-call? .game-items buy-item u1 u1)
```

### Upgrading an Item

```clarity
(contract-call? .game-items upgrade-item u1)
```

## Integration Guide

### Integrating with Your Game

1. Deploy this contract to the Stacks blockchain
2. Use the contract functions to create your initial item catalog
3. Implement client-side code to interact with the contract
4. Use the contract's read-only functions to display item information
5. Implement marketplace UI to allow users to buy and sell items

### Tips for Game Developers

- Create a consistent item type taxonomy
- Consider rarity levels and their implications
- Design upgrade paths carefully
- Monitor marketplace activity
- Consider setting reasonable admin fees

## Security Considerations

- Only the contract owner can add creators to the whitelist
- Only creators and the contract owner can mint new items
- Items must be marked as tradeable to be transferred or listed
- All marketplace listings have an expiration
- Admin fee is capped at 10%