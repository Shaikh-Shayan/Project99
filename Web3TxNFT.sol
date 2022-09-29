// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts@4.7.3/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts@4.7.3/access/Ownable.sol";
import "@openzeppelin/contracts@4.7.3/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts@4.7.3/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts@4.7.3/security/ReentrancyGuard.sol";
import "./NFT.sol";

//["0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2","0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db","0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB","0x23079599b4950D89429F1C08B2ed2DC820955Fd5"]
contract NFT is ERC1155, ERC1155Burnable, EIP712, Ownable, ReentrancyGuard {
   
    event NFTPurchased(
        uint256 tokenId,
        uint256 nonce,
        uint256 copies,
        address buyer,
        uint256 amount
    );
    
    event Airdropped(address account, uint256 amount, uint256 tokenId);
   
    //event NotAirdropped(address account, uint256 tokenId);
    
    event Claimed(address account, uint256 amount, uint256 tokenId);
    
    event NFTBurned(address account, uint256 tokenId);
    
    event RemovedFromAllowlist(address account, uint256 tokenId);
    
    event AddedToAllowlist(address account, uint256 tokenId);

    string private constant SIGNING_DOMAIN = "Voucher-Domain";
    string private constant SIGNING_VERSION = "1";
    
    // mapping(uint256 => uint256) MAX_COPIES;
    // mapping(uint256 => uint256) public minted;
    // uint256 creationTime;
    // uint256 burnTime;

    
    struct NFTVoucher {
        uint256 tokenId;
        uint256 minPrice;
        uint256 copies;
        address artist;
        /*The signature proves that the NFT creator authorized the creation 
        of the specific NFT described in the voucher.
        */
        bytes signature;
    }

    // struct NFTAirdrop{
    //     address receiver;
    //     uint256 amount;
    // }

    
    NFTDetail nftDetail;

    constructor(address _nftDetail)
        ERC1155(
            "ipfs://bafybeidcf6zgua6jmzxpmhq6uey3izacstycsneeleyvhjnozmm5djyxcq/{id}.json"
        )
        EIP712(SIGNING_DOMAIN, SIGNING_VERSION)
    {
        nftDetail = NFTDetail(_nftDetail);
    }

    modifier isValidId(uint256 tokenId){
        require(nftDetail.getNFTDetails(tokenId).isSet);
        _;
    }
    

    /*
    function 'redeem' takes a voucher as an argument and lets the user redeem the signed voucher
    The NFTVoucher-type member 'voucher' takes voucher
    The address-type member 'account' takes buyer's address
    The uint256-type member 'nonce' takes nonce
    */
    function redeem(
        NFTVoucher calldata voucher,
        uint256 nonce,
        uint256 copies
    ) public payable nonReentrant isValidId(voucher.tokenId){
        /*
        Check wether address is present in the allowlist
        */
        NFTDetail.nft memory nftPass = nftDetail.getNFTDetails(voucher.tokenId);

        address buyer = msg.sender;
        require(
            nftDetail.getAllowlisted(voucher.tokenId,buyer),
            "Address not present in the allowlist"
        );
        /*
        Check if the signature is valid and belongs to the account that's authorized to mint NFTs
        */
        address signer = _verify(voucher);
        require(signer == voucher.artist, "Invalid signer");

        /*
        Check to see if user has already used the signature
        */
        require(!nftDetail.voucherUsed(nonce), "This voucher has already been used.");

        // require(
        //     voucher.tokenId == 1 || voucher.tokenId == 2,
        //     "Token doesn't exist"
        // );
        require(
            nftPass.minted + copies <= nftPass.maxCopies,
            "Not enough supply"
        );
        require(
            msg.value >= nftPass.price * copies * 1 wei,
            "Not enough ethers sent"
        );

        /*
        transferring the funds to the owner
        */
        payable(owner()).transfer(msg.value);

        /*
        minting NFT
        */
        _mint(buyer, voucher.tokenId, copies, "");
        nftPass.minted += copies;
        nftDetail.setVoucherUsed(nonce);

        /*
        airdropping MemberPass NFT to the long horn NFT buyers
        */
        if(nftPass.rewardNFT.length != 0){
            for(uint256 j = 0; j < nftPass.rewardNFT.length; j++){
                nftDetail.setAirdroppedAmount(nftPass.rewardNFT[j], buyer, 1);
            }
        } 
        emit NFTPurchased(voucher.tokenId, nonce, copies, buyer, msg.value);
    }

   
    function checkEligibility(uint256 tokenId, address account)
        public
        view
        isValidId(tokenId)
        returns (string memory, bool)
    {
        if(nftDetail.getAllowlisted(tokenId, account)){
            if(nftDetail.getClaimedAmount(tokenId, account) == 0){
                return ("You can claim your NFT", true);
            }else{
                return ("You have already claimed this NFT", false);
            }
        }else{
            return ("Your address is not present in the allowlist", false);
        }
    }

    
    /*
    The function 'claim' mints the nft to the address(msg.sender) who was aidropped the nft 
    The address-type input 'account' takes receiver's address
    The uint256-type input 'tokenId' takes Token ID
    */
    function claim(uint256 tokenId) external nonReentrant isValidId(tokenId){
        address account = msg.sender;
        NFTDetail.nft memory nftPass = nftDetail.getNFTDetails(tokenId);

        uint256 amount = nftDetail.getAirdroppedAmount(tokenId,account) -
            nftDetail.getClaimedAmount(tokenId,account);

        require(amount > 0, "You don't have any NFT!");

        

        _mint(account, tokenId, amount, "");
        nftPass.minted += amount;
        nftDetail.setClaimedAmount(tokenId, account, amount);
        
        emit Claimed(account, amount, tokenId);
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
    ) public override isValidId(id){
        NFTDetail.nft memory nftPass = nftDetail.getNFTDetails(id);
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        /*
        Require statement checks that the time has exceeded burn rate, i.e., 1 year
        */
        require(
            block.timestamp > nftPass.burnTime,
            "You are not allowed to burn the nft before 1 year"
        );

        emit NFTBurned(account, id);
        super.burn(account, id, value);
    }

     /*
    The function '_beforeTokenTransfer' ensures that NFT is non-transferable 
    */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override{

        NFTDetail.nft memory nftPass = nftDetail.getNFTDetails(ids[0]);
        require(nftPass.isSet,"TokenId doesn't exists");
        if(nftPass.isTransferrable){
            super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        }
        else{
            require(
                from == address(0) || to == address(0),
                "You can't transfer this NFT"
            );
        }
        
    }

    /*
    The function '_afterTokenTransfer' emits the event based on whether token is minted or burned.
    */
    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        NFTDetail.nft memory nftPass = nftDetail.getNFTDetails(ids[0]);
        require(nftPass.isSet,"TokenId doesn't exists");

        if(nftPass.isTransferrable){
            super._afterTokenTransfer(operator, from, to, ids, amounts, data);
        }
    }

    

    /*
    The function '_verify' verifies signature against input and recovers address, 
    or reverts transaction if signature is invalid
    The NFTVoucher-type input 'voucher' takes voucher
    */
    function _verify(NFTVoucher calldata voucher)
        public
        view
        returns (address)
    {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }

    /*
    The function '_hash' returns the hash of the argument passed
    The NFTVoucher-type input 'voucher' takes voucher
    */
    function _hash(NFTVoucher calldata voucher)
        internal
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256(
                            "NFTVoucher(uint256 tokenId,uint256 minPrice,uint256 copies,address artist)"
                        ),
                        voucher.tokenId,
                        voucher.minPrice,
                        voucher.copies,
                        voucher.artist
                    )
                )
            );
    }
}
