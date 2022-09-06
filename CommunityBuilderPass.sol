// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/ECDSA.sol";

contract CommunityBuilderPass is ERC1155, Ownable, ERC1155Burnable, EIP712{
    event Attest(address indexed to, uint256 indexed tokenId);
    event Revoke(address indexed to, uint256 indexed tokenId);

    struct NFTVoucher {
        uint256 tokenId;
        uint256 minPrice;
        string uri;
        address buyer;
        bytes signature;
    }

    string private constant SIGNING_DOMAIN = "Voucher-Domain";
    string private constant SIGNING_VERSION = "1";
    uint256 immutable MAX_SUPPLY;
    uint256 minted = 0;
    mapping(address => mapping(uint256 => bool)) redeemed;
    address private minter;

    constructor(address signer, uint256 maxSupply) ERC1155("CommunityBuilderPass") EIP712(SIGNING_DOMAIN, SIGNING_VERSION){
        minter = signer;
        MAX_SUPPLY = maxSupply;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function redeem(NFTVoucher calldata voucher)
        public
        payable
    {   
        require(minter == _verify(voucher), "Invalid signer");
        require(redeemed[voucher.buyer][voucher.tokenId] != true, "Already redeemed!");
        require(voucher.tokenId == 1 , "Token doesn't exist");
        require(minted + 1 <= MAX_SUPPLY, "Not enough supply");
        require(msg.value >= voucher.minPrice, "Not enough ethers sent");

        _mint(voucher.buyer, voucher.tokenId, 1, "");

        minted += 1;
        redeemed[voucher.buyer][voucher.tokenId] = true;
    }

    //function mint(address account, uint256 id)
    //  public
    //   payable
    //{   
    //    require(id==1, "Token doesn't exists");
    //    require(minted+1 <= MAX_SUPPLY, "Not enough supply");
    //    require(msg.value >= 1 ether, "Not enough amount sent to buy NFT");
    //    _mint(account, id, 1, "");
    //    minted += 1;
    //}
    
    function burn(uint256 tokenId)
        external 
    {
        require(balanceOf(msg.sender, tokenId) > 1, "You do not own any NFT!");
        _burn(msg.sender, tokenId, 1);
    }

    function revoke(address tokenOwner, uint256 tokenId)
        external 
        onlyOwner
    {
        _burn(tokenOwner, tokenId, 1);
    }

    function withdraw() public onlyOwner{
        require(address(this).balance >0, "Balance is 0");
        payable(owner()).transfer(address(this).balance);
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal 
        override 
        virtual 
    {
        require(from == address(0) || to == address(0), "You can't transfer this NFT");
    }

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

    function _verify(NFTVoucher calldata voucher) internal view returns (address) {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }

    function _hash(NFTVoucher calldata voucher) internal view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(
            keccak256("NFTVoucher(uint256 tokenId,uint256 minPrice,string uri,address buyer)"),
            voucher.tokenId,
            voucher.minPrice,
            keccak256(bytes(voucher.uri)),
            voucher.buyer
        )));
    }



}
