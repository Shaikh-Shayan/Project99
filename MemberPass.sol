// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@4.7.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts@4.7.3/access/AccessControl.sol";

contract MemberPass is ERC1155, ERC1155Burnable, EIP712, Ownable, AccessControl {
    event Reedemed(address indexed buyer, uint256 indexed tokenId);

    string private constant SIGNING_DOMAIN = "Voucher-Domain";
    string private constant SIGNING_VERSION = "1";
    uint256 immutable MAX_SUPPLY;
    uint256 minted = 0;
    uint256 creationTime;
    uint256 burnTime;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    //NFT Voucher contains all the information that will go in the actual NFT
    struct NFTVoucher {
        uint256 tokenId;
        uint256 minPrice;
        string uri;
        address buyer;
        //The signature proves that the NFT creator authorized the creation of the specific NFT described in the voucher.
        bytes signature;
    }

    //Signature Tracker
    mapping(bytes => bool) public signatureUsed;
    
    constructor(address signer, uint256 maxSupply) ERC1155("MemberPass") EIP712(SIGNING_DOMAIN, SIGNING_VERSION) {
        _setupRole(MINTER_ROLE, signer);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        creationTime = block.timestamp;
        //365(days)*24(hours)*60(minutes)*60(seconds) = 31536000 seconds
        burnTime = creationTime + 31536000;
        MAX_SUPPLY = maxSupply;
    }

    //sets the base URI
    function setURI(string memory newuri) public onlyOwner{
        _setURI(newuri);
    }

    //takes a voucher as an argument and let's the user redeem the signed voucher
    function redeem(NFTVoucher calldata voucher)
        public
        payable
    {   
        //Check if the signature is valid and belongs to the account that's authorized to mint NFTs
        address signer = _verify(voucher);
        require(hasRole(MINTER_ROLE, signer), "Invalid signer");

        //Check to see if user has already used the signature
        require(!signatureUsed[voucher.signature], "Signature has already been used.");
        
        //This contract represents only 1 single NFT hence only tokenId 1 is possible
        require(voucher.tokenId == 1, "Token doesn't exist");
        
        require(minted+1< MAX_SUPPLY, "Not enough supply");
        require(msg.value >= voucher.minPrice, "Not enough ethers sent");

        _mint(voucher.buyer, voucher.tokenId, 1, "");

        minted += 1;
        signatureUsed[voucher.signature] = true;

        emit Reedemed(voucher.buyer, voucher.tokenId);
    }
    
    //burns the nft only after 1 year
    function burn(
        address account,
        uint256 id,
        uint256 value
    ) public override {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        //burn rate:- 1 year
        require(block.timestamp > burnTime, "You are not allowed to burn the nft before 1 year");
        super.burn(account, id, value);
    }

    //let's the owner withdraw the funds from the contract
    function withdraw() public onlyOwner{
        require(address(this).balance >0, "Balance is 0");
        payable(owner()).transfer(address(this).balance);
    }

    //verifies signature against input and recovers address, or reverts transaction if signature is invalid
     function _verify(NFTVoucher calldata voucher) internal view returns (address) {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }

    //returns the hash of the argument passed
    function _hash(NFTVoucher calldata voucher) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
            keccak256("NFTVoucher(uint256 tokenId,uint256 minPrice,string uri,address buyer)"),
            voucher.tokenId,
            voucher.minPrice,
            keccak256(bytes(voucher.uri)),
            voucher.buyer
        )));
    }

    //override required by solidity
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
