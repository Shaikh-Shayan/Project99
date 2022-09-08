// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@4.7.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts@4.7.3/access/AccessControl.sol";

contract CommunityBuilderPass is ERC1155, Ownable, ERC1155Burnable, EIP712, AccessControl{
    event Attest(address indexed to, uint256 indexed tokenId);
    event Revoke(address indexed to, uint256 indexed tokenId);
    event Reedemed(address indexed buyer, uint256 indexed tokenId);

    //NFT Voucher contains all the information that will go in the actual NFT
    struct NFTVoucher {
        uint256 tokenId;
        uint256 minPrice;
        string uri;
        address buyer;
        //The signature proves that the NFT creator authorized the creation of the specific NFT described in the voucher.
        bytes signature;
    }

    string private constant SIGNING_DOMAIN = "Voucher-Domain";
    string private constant SIGNING_VERSION = "1";
    uint256 immutable MAX_SUPPLY;
    uint256 minted = 0;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    //signature tracker
    mapping(bytes => bool) signatureUsed;

    constructor(address signer, uint256 maxSupply) ERC1155("CommunityBuilderPass") EIP712(SIGNING_DOMAIN, SIGNING_VERSION){
        _setupRole(MINTER_ROLE, signer);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        MAX_SUPPLY = maxSupply;
    }

    //sets the base URI
    function setURI(string memory newuri) public onlyOwner {
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
        require(voucher.tokenId == 1 , "Token doesn't exist");
        
        require(minted + 1 <= MAX_SUPPLY, "Not enough supply");
        require(msg.value >= voucher.minPrice, "Not enough ethers sent");

        _mint(voucher.buyer, voucher.tokenId, 1, "");

        minted += 1;
        signatureUsed[voucher.signature] = true;

        emit Reedemed(voucher.buyer, voucher.tokenId);
    }
    
    //let's the owner withdraw funds from the contract
    function withdraw() public onlyOwner{
        require(address(this).balance >0, "Balance is 0");
        payable(owner()).transfer(address(this).balance);
    }

    //makes NFT non-transferrable
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
