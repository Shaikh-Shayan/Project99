// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@4.7.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/extensions/ERC1155Burnable.sol";

contract CommunityBuilderPass is ERC1155, Ownable, ERC1155Burnable{

    event Attest(address indexed to, uint256 indexed tokenId);
    event Revoke(address indexed to, uint256 indexed tokenId);

    event Airdropped(address account, uint256 tokenId);
    event Claimed(address account, uint256 tokenId);

    event RemovedFromAllowlist(address account, uint256 tokenId);
    event AddedToAllowlist(address account, uint256 tokenId);
    event NotAirdropped(address account, uint256 tokenId);

    mapping(uint256 => uint256) MAX_SUPPLY;
    mapping(uint256 => uint256) minted;
    uint256 creationTime;
    uint256 burnTime;

    mapping(uint256=>mapping(address => bool)) public claimed;
    mapping(uint256=>mapping(address => bool)) public allowlist;
    mapping(uint256=>mapping(address => bool)) public airdropped;

    constructor(uint256 socialPassMaxSupply, uint256 contentPassMaxSupply,address[] memory _whitelistForSocialPass, address[] memory _whitelistForContentPass) ERC1155("CommunityBuilderPass"){
        creationTime = block.timestamp;
        //365(days)*24(hours)*60(minutes)*60(seconds) = 31536000 seconds
        burnTime = creationTime + 31536000;
        MAX_SUPPLY[1] = socialPassMaxSupply;
        MAX_SUPPLY[2] = contentPassMaxSupply;

        for(uint i=0; i< _whitelistForSocialPass.length; i++){
            allowlist[1][_whitelistForSocialPass[i]] = true;
        }

        for(uint i=0; i< _whitelistForContentPass.length; i++){
            allowlist[2][_whitelistForContentPass[i]] = true;
        }
    }

    //mints the NFT to the account
    function mint(address account, uint256 id)
        internal
    {   
        //This contract represents only 2 NFT hence only tokenId 1 and 2 are possible
        require(id==1 || id == 2, "Token doesn't exists");

        //check if number of minted nft exceeds Maximum Supply
        require(minted[id]+1 <= MAX_SUPPLY[id], "Not enough supply");

        _mint(account, id, 1, "");
        minted[id] += 1;
    }

    //airdrops nfts to all the accounts passed as paramater to the function
    function airdrop(uint256 tokenId, address[] memory accounts) 
        external
        onlyOwner 
    {
        require(tokenId == 1 || tokenId == 2, "TokenId doesn't exists!");

        for(uint i = 0; i < accounts.length; i++) {
            //Skip the address if it's not present in the allowlist or if it has been airdropped nft already
            if(allowlist[tokenId][accounts[i]] == false || airdropped[tokenId][accounts[i]] == true ){
                emit NotAirdropped(accounts[i], tokenId);
                continue;
            }

            airdropped[tokenId][accounts[i]] = true;
            emit Airdropped(accounts[i], tokenId);
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
    function claim(uint256 tokenId) external {

        require(tokenId == 1 || tokenId == 2, "TokenId doesn't exists!");
        require(airdropped[tokenId][msg.sender] == true, "You don't have any NFT!");
        require(claimed[tokenId][msg.sender] == false, "NFT Already Claimed!");

        claimed[tokenId][msg.sender] = true;

        mint(msg.sender, tokenId);
        
        emit Claimed(msg.sender, tokenId);
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

    function withdraw() public onlyOwner{
        require(address(this).balance >0, "Balance is 0");
        payable(owner()).transfer(address(this).balance);
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
            emit Attest(to, ids[0]);
        }else if(to == address(0)){
            emit Revoke(to, ids[0]);
        }

    }

}