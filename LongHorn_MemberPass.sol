// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@4.7.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/extensions/ERC1155Burnable.sol";

//["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db","0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB"]
contract ContentContributorPass is ERC1155, Ownable, ERC1155Burnable{
    event Attest(address indexed to, uint256 indexed tokenId);
    event Revoke(address indexed to, uint256 indexed tokenId);

    event Airdropped(address account, uint256 tokenId);
    event Claimed(address account, uint256 tokenId);
    event RemovedFromAllowlist(address account);
    event AddedToAllowlist(address account);
    event NotAirdropped(address account);

    uint256 immutable MAX_SUPPLY;
    uint256 minted = 0;
    uint256 creationTime;
    uint256 burnTime;

    mapping(address => bool) public claimed;
    mapping(address => bool) public allowlist;
    mapping(address => bool) public airdropped;

    constructor(uint256 maxSupply, address[] memory _whitelist) ERC1155("MemberPass") {
        require(_whitelist.length > 0, "Empty allowlist provided");
        creationTime = block.timestamp;
        //1(year) * 365(days) * 24(hours) * 60(min) * 60(sec) = 31536000 seconds
        burnTime = creationTime + 31536000;
        MAX_SUPPLY = maxSupply;

        for(uint i=0; i< _whitelist.length; i++){
            allowlist[_whitelist[i]] = true;
        }
    }

    //sets the base URI
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    //mints the nft to the account
    function mint(address account, uint256 id)
        internal
    {   
        //This contract represents only 1 single NFT hence only tokenId 1 is possible
        require(id==1, "Token doesn't exists");

        //check if number of minted nft exceeds Maximum Supply
        require(minted+1 <= MAX_SUPPLY, "Not enough supply");

        _mint(account, id, 1, "");
        minted += 1;
    }

    //airdrops nfts to all the accounts passed as paramater to the function
    function airdrop(uint256 tokenId, address[] memory accounts) 
        external
        onlyOwner 
    {
        require(tokenId == 1, "TokenId doesn't exists!");

        for(uint i = 0; i < accounts.length; i++) {
            //Skip the address if it's not present in the allowlist or if it has been airdropped nft already
            if(allowlist[accounts[i]] == false || airdropped[accounts[i]] == true ){
                emit NotAirdropped(accounts[i]);
                continue;
            }
            airdropped[accounts[i]] = true;
            emit Airdropped(accounts[i], tokenId);
        }
    }

    //adds the list of addresses to the Allowlist
    function addToAllowlist(address[] memory _recipients) 
        external
        onlyOwner 
    {
        for(uint i = 0; i < _recipients.length; i++) {
            allowlist[_recipients[i]] = true;
            emit AddedToAllowlist(_recipients[i]);
        }
    }

    //removes the list of addresses from the allowlist
    function removeFromAllowlist(address[] memory _recipients) 
        external 
        onlyOwner
    {
        for(uint i = 0; i < _recipients.length; i++) {
            allowlist[_recipients[i]] = false;
            emit RemovedFromAllowlist(_recipients[i]);
        }
    }

    //mints the nft to the address(msg.sender) who was aidropped the nft 
    function claim() external {
        require(airdropped[msg.sender] == true, "You don't have any NFT!");
        require(claimed[msg.sender] == false, "NFT Already Claimed!");

        claimed[msg.sender] = true;

        mint(msg.sender, 1);
        
        emit Claimed(msg.sender, 1);
    }

    function burn( address account, uint256 id, uint256 value) 
        public 
        override 
    {
        require(account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );

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
            emit Attest(to, ids[0]);
        }else if(to == address(0)){
            emit Revoke(to, ids[0]);
        }

    }
}
