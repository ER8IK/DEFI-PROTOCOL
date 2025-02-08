// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";


contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    address public OWNER = msg.sender;
    address public user = USER; // Declare user variable
    DSCEngine public dscEngine = dsce; // Declare dscEngine variable
    ERC20Mock public collateralToken = ERC20Mock(weth); // Declare collateralToken variable
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

     ////////////////////////////
    ///   constructor tests  ////
    ////////////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    ////////////////////////////
    ///   Price Test        ////
    ////////////////////////////

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dsce.getUsdValue(weth, ethAmount);
        assertEq(expectedUsd, actualUsd);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dsce.getTokenAmountFromUsd(weth, usdAmount);
        assertEq(expectedWeth, actualWeth);
    }

    
    ////////////////////////////////////
    ///   depositCollateral Tests   ////
    ////////////////////////////////////

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__MustBeMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock ranToken = new ERC20Mock();
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NotAllowedToken.selector);
        dsce.depositCollateral(address(ranToken), AMOUNT_COLLATERAL);
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    
    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
    (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(USER);

    uint256 expectedTotalDscMinted = 0;
    uint256 expectedCollateralValueInUsd = dsce.getUsdValue(weth, AMOUNT_COLLATERAL);

    // Проверяем, что общее количество выпущенных DSC равно ожидаемому (нулю)
    assertEq(totalDscMinted, expectedTotalDscMinted, "Total DSC minted does not match expected");

    // Проверяем, что значение залога в USD корректное
    assertEq(collateralValueInUsd, expectedCollateralValueInUsd, "Collateral value in USD mismatch");
}

     ////////////////////////////////////
    ///   mintdsc      Tests       ////
    ////////////////////////////////////
    function testRevertsIfMintingWithoutCollateral() public {
        vm.startPrank(USER);
            vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 0));
        dsce.mintDsc(100 ether);
        vm.stopPrank();
    }

    function testCanMintDscAfterCollateralDeposit() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 mintAmount = 100 ether;
        dsce.mintDsc(mintAmount);
        (uint256 totalDscMinted,) = dsce.getAccountInformation(USER);
        assertEq(totalDscMinted, mintAmount, "Minted DSC does not match expected amount");
        vm.stopPrank();
    }

    function testRevertsIfMintingExceedsLimit() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        dsce.depositCollateral(weth, AMOUNT_COLLATERAL);

        uint256 excessiveMintAmount = 1_000_000 ether;
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, 1e16));
        dsce.mintDsc(excessiveMintAmount);
        vm.stopPrank();
    }

     ////////////////////////////////////
    ///   Burn         Tests         ////
    ////////////////////////////////////
    // function testBurnDsc() public {
    //     uint256 amountToBurn = 5 ether;
    //     vm.startPrank(USER);      
    //     uint256 balanceBefore = dsc.balanceOf(USER);
    //     assertEq(balanceBefore, 10 ether);
    //     dsce.burnDsc(amountToBurn);
    //     uint256 balanceAfter = dsc.balanceOf(USER);
    //     assertEq(balanceAfter, 5 ether);
    //     vm.stopPrank();
    // }
}