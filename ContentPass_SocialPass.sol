// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@4.7.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/extensions/ERC1155Burnable.sol";

//["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db","0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB","0x23079599b4950D89429F1C08B2ed2DC820955Fd5"]

contract CommunityBuilderPass is ERC1155, Ownable, ERC1155Burnable{

    event Airdropped(address account, uint256 amount, uint256 tokenId);
    event NotAirdropped(address account, uint256 tokenId);
    event Claimed(address account, uint256 amount, uint256 tokenId);
    event NFTMinted(address account, uint256 tokenId);
    event NFTBurned(address account, uint256 tokenId);
    event RemovedFromAllowlist(address account, uint256 tokenId);
    event AddedToAllowlist(address account, uint256 tokenId);
    
    mapping(uint256 => uint256) MAX_COPIES;
    mapping(uint256 => uint256) minted;
    uint256 creationTime;
    uint256 burnTime;

    mapping(uint256=>mapping(address => bool)) public allowlist;
    mapping(uint256=>mapping(address => uint256)) public airdropped;

    struct NFTAirdrop{
        address receiver;
        uint256 amount;
    }

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

    //airdrops nfts to the account passed as param to the function
    function airdrop(uint256 tokenId, address account, uint256 amount) 
        external
        onlyOwner 
    {
        require(tokenId == 1 || tokenId == 2, "TokenId doesn't exists!");

        //check if number of airdropped nft exceeds Maximum Supply
        require(minted[tokenId]+1 <= MAX_COPIES[tokenId], "Not enough supply");

        require(allowlist[tokenId][account], "Address not present in the allowlist");

        airdropped[tokenId][account] += amount;
        emit Airdropped(account, amount, tokenId);
        
    }

    //airdrops nfts to all the accounts passed as paramater to the function
    function airdropToMultipleAccount(uint256 tokenId, NFTAirdrop[] memory toAirdrop) 
        external
        onlyOwner 
    {
        require(tokenId == 1 || tokenId == 2, "TokenId doesn't exist");

        for(uint256 i =0; i < toAirdrop.length; i++){
            address receiver = toAirdrop[i].receiver;
            uint256 amount = toAirdrop[i].amount;
            //check if number of airdropped nft exceeds Maximum Supply
            require(minted[tokenId] + amount <= MAX_COPIES[tokenId], "Not enough supply");
            
            if(allowlist[tokenId][receiver]){
                airdropped[tokenId][receiver] += amount;
                emit Airdropped(receiver, amount, tokenId);
            }else{
                emit NotAirdropped(receiver, tokenId);
            }
        
        }
    }


    //adds the list of addresses to the Allowlist
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

    //removes the list of addresses from the allowlist
    function removeFromAllowlist(address[] memory _recipients, uint256 tokenId) 
        external 
        onlyOwner
    {
        for(uint i = 0; i < _recipients.length; i++) {
            allowlist[tokenId][_recipients[i]] = false;
            emit RemovedFromAllowlist(_recipients[i], tokenId);
        }
    }

    //mints the nft to the address(msg.sender) who was aidropped the nft 
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

    //update the number of copies
    function updateCopies(uint256 tokenId, uint256 newCopies) 
        public 
        onlyOwner
    {
        require(tokenId == 1|| tokenId == 2, "TokenId doesn't exists");
        require(newCopies>0, "Copies cannot be zero");

        MAX_COPIES[tokenId] = newCopies;
    }

    //sets the base URI
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    //burns the nft only after 1 year
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
        //burn rate:- 1 year
        require(block.timestamp > burnTime, "You are not allowed to burn the nft before 1 year");
        super.burn(account, id, value);
    }
    
    //ensures that NFT is non-transferable 
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal 
        override 
        virtual 
    {
        require(from == address(0) || to == address(0), "You can't transfer this NFT");
    }

    //emits the event base on whether token is minted or burned.
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
