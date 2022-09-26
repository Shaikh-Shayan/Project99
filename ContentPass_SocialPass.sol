// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@4.7.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/extensions/ERC1155Burnable.sol";

//["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db","0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB","0x23079599b4950D89429F1C08B2ed2DC820955Fd5"]

contract CommunityBuilderPass is ERC1155, Ownable, ERC1155Burnable{

    /*
    @dev The event 'Airdropped' must be emitted when an account is airdropped tokens
    The address-type member 'account' takes receiver's address
    The uint256-type member 'amount' takes token amount
    The uint256-type member 'tokenId' takes Token ID
    */
    event Airdropped(address account, uint256 amount, uint256 tokenId);
    /*
    @dev The event 'NotAirdropped' must be emitted when an airdrop fails
    The address-type member 'account' takes receiver's address
    The uint256-type member 'tokenId' takes Token ID
    */
    event NotAirdropped(address account, uint256 tokenId);
    /*
    @dev The event 'Claimed' must be emitted when an airdrop is claimed
    The address-type member 'account' takes receiver's address
    The uint256-type member 'amount' takes token amount
    The uint256-type member 'tokenId' takes Token ID
    */
    event Claimed(address account, uint256 amount, uint256 tokenId);
    /*
    @dev The event 'NFTMinted' must be emitted when an NFT is minted to an address
    The address-type member 'account' takes receiver's address
    The uint256-type member 'tokenId' takes Token ID
    */
    event NFTMinted(address account, uint256 tokenId);
    /*
    @dev The event 'NFTBurned' must be emitted when an NFT is burned from an address
    The address-type member 'account' takes receiver's address
    The uint256-type member 'tokenId' takes Token ID
    */
    event NFTBurned(address account, uint256 tokenId);
    /*
    @dev The event 'RemovedFromAllowlist' must be emitted when an address is removed from allowlist
    The address-type member 'account' takes receiver's address
    The uint256-type member 'tokenId' takes Token ID
    */
    event RemovedFromAllowlist(address account, uint256 tokenId);
    /*
    @dev The event 'AddedToAllowlist' must be emitted when an address is added to allowlist
    The address-type member 'account' takes receiver's address
    The uint256-type member 'tokenId' takes Token ID
    */
    event AddedToAllowlist(address account, uint256 tokenId);
    /*
    The mapping 'MAX_COPIES' stores maximum number of copies
    The mapping 'minted' stores minted number of copies
    */
    mapping(uint256 => uint256) MAX_COPIES;
    mapping(uint256 => uint256) minted;
    uint256 creationTime;
    uint256 burnTime;
    /*
    The mapping 'allowlist' stores allowlist/whitelist addresses
    The mapping 'airdropped' stores number of tokens airdropped to an address
    */
    mapping(uint256=>mapping(address => bool)) public allowlist;
    mapping(uint256=>mapping(address => uint256)) public airdropped;
    /*
    The struct 'NFTAirdrop' is a struct for airdrops
    The address-type member 'receiver' stores receiver's address
    The uint256-type member 'amount' stores token amount
    */
    struct NFTAirdrop{
        address receiver;
        uint256 amount;
    }

    /*
    The contract constructor takes 4 arguments while deploying
    The uint256-type input 'contentPassCopies' takes number of copies for Content Pass
    The uint256-type input 'socialPassCopies' takes number of copies for Social Pass
    The address[]-type input '_whitelistForContentPass' takes whitelisted addresses for Content Pass
    The address[]-type input '_whitelistForSocialPass' takes whitelisted addresses for Social Pass
    */
    constructor(uint256 contentPassCopies, uint256 socialPassCopies,address[] memory _whitelistForContentPass, address[] memory _whitelistForSocialPass) ERC1155("CommunityBuilderPass"){
        creationTime = block.timestamp;
        //365(days)*24(hours)*60(minutes)*60(seconds) = 31536000 seconds
        burnTime = creationTime + 31536000;
        MAX_COPIES[1] = contentPassCopies;
        MAX_COPIES[2] = socialPassCopies;

        for(uint i=0; i< _whitelistForContentPass.length; i++){
            allowlist[1][_whitelistForContentPass[i]] = true;
        }

        for(uint i=0; i< _whitelistForSocialPass.length; i++){
            allowlist[2][_whitelistForSocialPass[i]] = true;
        }
    }
    /*
    The function 'airdrop' can only be called by owner, 
    and airdrops nfts to the account passed as param to the function
    The uint256-type member 'tokenId' takes Token ID
    The address-type member 'account' takes receiver's address
    The uint256-type member 'amount' takes token amount
    */
    function airdrop(uint256 tokenId, address account, uint256 amount) 
        external
        onlyOwner 
    {
        require(tokenId == 1 || tokenId == 2, "TokenId doesn't exists!");

        /*
        The require statement checks if number of airdropped nft exceeds Maximum Supply
        */
        require(minted[tokenId]+1 <= MAX_COPIES[tokenId], "Not enough supply");

        require(allowlist[tokenId][account], "Address not present in the allowlist");

        airdropped[tokenId][account] += amount;
        emit Airdropped(account, amount, tokenId);
        
    }

    /*
    The function 'airdropToMultipleAccount' can only be called by owner, 
    and airdrops nfts to all the accounts passed as paramater to the function
    The uint256-type member 'tokenId' takes Token ID
    The NFTAirdrop[]-type input 'toAirdrop' takes array of 'NFTAirdrop' structs
    */
    function airdropToMultipleAccount(uint256 tokenId, NFTAirdrop[] memory toAirdrop) 
        external
        onlyOwner 
    {
        require(tokenId == 1 || tokenId == 2, "TokenId doesn't exist");

        for(uint256 i =0; i < toAirdrop.length; i++){
            address receiver = toAirdrop[i].receiver;
            uint256 amount = toAirdrop[i].amount;
            /*
            The require statement checks if number of airdropped nft exceeds Maximum Supply
            */
            require(minted[tokenId] + amount <= MAX_COPIES[tokenId], "Not enough supply");
            
            if(allowlist[tokenId][receiver]){
                airdropped[tokenId][receiver] += amount;
                emit Airdropped(receiver, amount, tokenId);
            }else{
                emit NotAirdropped(receiver, tokenId);
            }
        
        }
    }


    /*
    The function 'addToAllowlist' adds the list of addresses to the Allowlist
    The address[]-type input '_recipients' takes addresses to add to the Allowlist
    The uint256-type input 'tokenId' takes Token ID
    */
    function addToAllowlist(address[] memory _recipients, uint256 tokenId) 
        external
        onlyOwner 
    {
        require(tokenId == 1 || tokenId == 2, "TokenId doesn't exists!");
        for(uint i = 0; i < _recipients.length; i++) {
            allowlist[tokenId][_recipients[i]] = true;
            emit AddedToAllowlist(_recipients[i], tokenId);
        }
    }

    /*
    The function 'removeFromAllowlist' removes the list of addresses from the Allowlist
    The address[]-type input '_recipients' takes addresses to remove from the Allowlist
    The uint256-type input 'tokenId' takes Token ID
    */
    function removeFromAllowlist(address[] memory _recipients, uint256 tokenId) 
        external 
        onlyOwner
    {
        for(uint i = 0; i < _recipients.length; i++) {
            allowlist[tokenId][_recipients[i]] = false;
            emit RemovedFromAllowlist(_recipients[i], tokenId);
        }
    }

    /*
    The function 'claim' mints the nft to the address(msg.sender) who was aidropped the nft 
    The address-type input 'account' takes receiver's address
    The uint256-type input 'tokenId' takes Token ID
    */
    function claim(address account, uint256 tokenId) 
        external 
    {
        uint256 amount = airdropped[tokenId][account];

        require(tokenId == 1 || tokenId == 2, "TokenId doesn't exists!");
        require(amount> 0, "You don't have any NFT!");

        airdropped[tokenId][account] = 0; 

        _mint(account, tokenId, amount, "");
        minted[tokenId] += amount;
        
        emit Claimed(account, amount, tokenId);
    }

    /*
    The function 'updateCopies' updates the number of copies
    The uint256-type input 'tokenId' takes Token ID
    The uint256-type input 'newCopies' takes new nmuber of copies
    */
    function updateCopies(uint256 tokenId, uint256 newCopies) 
        public 
        onlyOwner
    {
        require(tokenId == 1|| tokenId == 2, "TokenId doesn't exists");
        require(newCopies>0, "Copies cannot be zero");

        MAX_COPIES[tokenId] = newCopies;
    }

    /*
    The function 'setURI' sets the base URI
    The string-type input 'newuri' takes the URI
    */
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    /*
    The function 'burn' burns the nft only after 1 year
    The address-type input 'account' takes  address
    The uint256-type input 'id' takes Token ID
    The uint256-type input 'value' takes value
    */
    function burn(
        address account,
        uint256 id,
        uint256 value
    ) public override {
        require(id == 1 || id == 2, "TokenId doesn't exists!");

        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        /*
        Require statement checks that the time has exceeded burn rate, i.e., 1 year
        */
        require(block.timestamp > burnTime, "You are not allowed to burn the nft before 1 year");
        super.burn(account, id, value);
    }
    
    /*
    The function '_beforeTokenTransfer' ensures that NFT is non-transferable 
    */
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal 
        override 
        virtual 
    {
        require(from == address(0) || to == address(0), "You can't transfer this NFT");
    }

    /*
    The function '_afterTokenTransfer' emits the event based on whether token is minted or burned.
    */
    function _afterTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal 
        override 
        virtual 
    {
        if(from == address(0)){
            emit NFTMinted(to, ids[0]);
        }else if(to == address(0)){
            emit NFTBurned(to, ids[0]);
        }

    }

}
