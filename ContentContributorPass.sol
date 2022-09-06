// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@4.7.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/extensions/ERC1155Burnable.sol";

//["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db","0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB"]
contract ContentContributorPass is ERC1155, Ownable, ERC1155Burnable{
    uint256 immutable MAX_SUPPLY;
    uint256 minted = 0;
    uint256 creationTime;
    uint256 burnTime;
    mapping(uint256 => bool) redeemed;

    mapping(address => bool) public claimed;
    mapping(address => bool) public allowlist;
    mapping(address => bool) public airdropped;

    event Airdropped(address account, uint256 tokenId);
    event Claimed(address account, uint256 tokenId);

    constructor(uint256 maxSupply, address[] memory _whitelist) ERC1155("MemberPass") {
        require(_whitelist.length > 0, "Empty allowlist provided");
        creationTime = block.timestamp;
        //5(year) * 365(days) * 24(hours) * 60(min) * 60(sec) = 157680000
        burnTime = creationTime + 157680000;
        MAX_SUPPLY = maxSupply;

        for(uint i=0; i< _whitelist.length; i++){
            allowlist[_whitelist[i]] = true;
        }
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mint(address account, uint256 id)
        public
        onlyOwner
    {   
        require(id==1, "Token doesn't exists");
        require(minted+1 <= MAX_SUPPLY, "Not enough supply");

        _mint(account, id, 1, "");
        minted += 1;
    }

    function burn( address account, uint256 id, uint256 value) 
        public 
        override 
    {
        require(account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );

        require(block.timestamp > burnTime, "You are not allowed to burn the nft before 5 years");
        super.burn(account, id, value);
    }

    //airdrops nfts to all the accounts passed as paramater to the function
    function airdrop(uint256 tokenId, address[] memory accounts) 
        external
        onlyOwner 
    {
        require(tokenId == 1, "TokenId doesn't exists!");

        for(uint i = 0; i < accounts.length; i++) {
            require(allowlist[accounts[i]] == true, "Address not present in the allowlist!");
            require(airdropped[accounts[i]] == false, "Already airdropped nft to this account!");

            airdropped[accounts[i]] = true;

            emit Airdropped(accounts[i], tokenId);
        }
    }


    function addToAllowlist(address[] memory _recipients) 
        external
        onlyOwner 
    {
        for(uint i = 0; i < _recipients.length; i++) {
            allowlist[_recipients[i]] = true;
        }
    }

    function removeFromAllowlist(address[] memory _recipients) 
        external 
        onlyOwner
    {
        for(uint i = 0; i < _recipients.length; i++) {
            allowlist[_recipients[i]] = false;
        }
    }

    function claim() external {
        require(allowlist[msg.sender] == true, "Address not present in the allowlist!");
        require(airdropped[msg.sender] == true, "You don't have any NFT!");
        require(claimed[msg.sender] == false, "NFT Already Claimed!");

        claimed[msg.sender] = true;

        _mint(msg.sender, 1, 1, "");
        
        emit Claimed(msg.sender, 1);
    }
}
