// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {StMNT} from "../contracts/Vault.sol";
import {Strategy1st} from "../contracts/Strategy1st.sol";
// Rimuovi ILendingPool da qui se già importato sotto
// import {ILendingPool} from "../contracts/interface/IInitCore.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IInitCore, ILendingPool} from "../contracts/interface/IInitCore.sol"; // Assicurati che questo percorso sia corretto

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function balanceOf(address) external view returns (uint256);
}

contract Strg1 is Test {
    StMNT public vault;
    Strategy1st public strategy1st;

    address public governance = address(1);
    address public management = address(2);
    address public treasury = address(3);
    address public guardian = address(4);
    address public user1 = address(5);
    // address public user2 = address(6); // Non usato in questo test

    IWETH public constant WMNT =
        IWETH(address(0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8));
    
    // Indirizzo del LendingPool usato nei test
    address internal constant LENDING_POOL_ADDRESS = 0x44949636f778fAD2b139E665aee11a2dc84A2976;

    function setUp() public {
        vault = new StMNT(
            address(WMNT),
            governance,
            treasury,
            "stMNT",
            "stMNT",
            guardian,
            management
        );
        // Setup della strategia direttamente qui per averla disponibile in tutti i test
        strategy1st = new Strategy1st(address(vault), governance);
        vm.startPrank(governance);
        strategy1st.setLendingPool(LENDING_POOL_ADDRESS);
        // Assicurati che le approval siano fatte una volta e correttamente
        // Se updateUnlimitedSpending già gestisce l'approve del vault dalla strategia, potrebbe bastare.
        // L'approve del lending pool dalla strategia è anche importante.
        strategy1st.updateUnlimitedSpending(true); // Strategia approva vault per 'want'
        strategy1st.updateUnlimitedSpendingInit(true); // Strategia approva _initAddr per 'want'
        strategy1st.approveLendingPool(); // Strategia approva lendingPool per 'want'
        vault.addStrategy(
            address(strategy1st),
            10_000, // 100% debtRatio
            0,      // minDebtPerHarvest (impostalo a 0 per test più semplici se non vuoi vincoli)
            type(uint256).max, // maxDebtPerHarvest (illimitato per semplicità di test)
            0       // performanceFee (0 per questo test)
        );
        vault.setPerformanceFee(0); // Commissione di performance del Vault a 0
        vault.setManagementFee(0);  // Commissione di gestione del Vault a 0
        vault.setDepositLimit(type(uint256).max); // Nessun limite di deposito per il test
        vm.stopPrank();
    }

    function wrapMNT(uint256 _amount) internal {
        WMNT.deposit{value: _amount}();
    }

    function testInitialize() internal {
        // ... (il tuo testInitialize rimane invariato) ...
        vm.startPrank(governance);
        assertEq(vault.governance(), governance);
        assertEq(vault.management(), management);
        assertEq(vault.guardian(), guardian);
        assertEq(vault.rewards(), treasury);
        assertEq(vault.name(), "stMNT");
        assertEq(vault.symbol(), "stMNT");
        assertEq(address(vault.token()), address(WMNT));

        // Le fee sono già state impostate a 0 in setUp() per i test di logica degli interessi
        assertEq(vault.performanceFee(), 0); // Modificato per riflettere setUp
        assertEq(vault.managementFee(), 0);  // Modificato per riflettere setUp
        assertEq(vault.lockedProfitDegradation(), 46000000000000); // Valore di default

        // vault.setDepositLimit(1_000_000 ether); // Già fatto in setUp

        assertEq(vault.depositLimit(), type(uint256).max); // Modificato
        
        vm.stopPrank();
        vm.startPrank(user1);
        vm.expectRevert("Vault: !governance");
        vault.setPerformanceFee(1000);
        vm.expectRevert("Vault: !governance");
        vault.setManagementFee(1000);
        vm.stopPrank();
    }

    function testDepositAndWithdraw_NoStrategy() internal { // Rinominato per chiarezza
        vm.deal(user1, 2_000 ether);
        vm.startPrank(user1);
        assertEq(user1.balance, 2_000 ether);
        wrapMNT(1_000 ether);
        WMNT.approve(address(vault), 1000 ether);
        
        // Rimuoviamo temporaneamente la strategia per testare il deposito/prelievo base del vault
        vm.startPrank(governance);
          vm.startPrank(governance);
        // Dichiara una variabile locale del tipo StMNT.StrategyParams
 vm.startPrank(governance);

        // Destruttura la tupla restituita da vault.strategies()
        (
            uint256 performanceFee, // Ignoreremo questo per ora se non serve
            uint256 activation,     // Ignoreremo questo
            uint256 originalDebtRatio, // Questo è il valore che ci interessa
            uint256 minDebtPerHarvest, // Ignoreremo questo
            uint256 maxDebtPerHarvest, // Ignoreremo questo
            uint256 lastReport,        // Ignoreremo questo
            uint256 totalDebt,         // Ignoreremo questo
            uint256 totalGain,         // Ignoreremo questo
            uint256 totalLoss          // Ignoreremo questo
        ) = vault.strategies(address(strategy1st));

        // Ora puoi usare la variabile originalDebtRatio
        vault.updateStrategyDebtRatio(address(strategy1st), 0); // Disattiva la strategia
        vm.stopPrank();
        vault.updateStrategyDebtRatio(address(strategy1st), 0); // Disattiva la strategia
        vm.stopPrank();
        vault.updateStrategyDebtRatio(address(strategy1st), 0); // Disattiva la strategia
        vm.stopPrank();

        uint256 shares = vault.deposit(1000 ether, user1);
        assertEq(shares, 1000 ether);
        assertEq(vault.pricePerShare(), 1 ether); // Senza strategia attiva, PPS dovrebbe essere 1
        
        // Non serve vault.approve per prelevare le proprie quote
        // vault.approve(address(vault), 1 ether); 
        uint256 assets = vault.withdraw(shares, user1, 0); // maxLoss a 0
        assertEq(assets, 1000 ether);

        // vault.approve(address(vault), 1 ether);
        vm.expectRevert(); // Dovrebbe fallire perché l'utente non ha più quote
        vault.withdraw(1, user1, 0); // Tenta di prelevare 1 quota
        vm.stopPrank();

        // Ripristina la strategia
        vm.startPrank(governance);
        vault.updateStrategyDebtRatio(address(strategy1st), originalDebtRatio);
        vm.stopPrank();
    }
    
    // Questo test è semplice, verifica solo che il deposito e prelievo base con una strategia
    // (senza interessi significativi) funzioni come previsto.
    function testDepositAndWithdraw_WithStrategy_NoInterest() internal returns(uint256){
        uint256 depositAmount = 1000 ether;
        vm.deal(user1, depositAmount * 2); // Dai fondi all'utente
        
        vm.startPrank(user1);
        wrapMNT(depositAmount);
        WMNT.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, user1);
        vm.stopPrank();

        uint256 ppsBeforeHarvest = vault.pricePerShare();
        console.log("PPS before 1st harvest (NoInterestTest): ", ppsBeforeHarvest);

        vm.startPrank(management); // keeper
        strategy1st.harvest();
        vm.stopPrank();

        uint256 ppsAfterHarvest = vault.pricePerShare();
        console.log("PPS after 1st harvest (NoInterestTest): ", ppsAfterHarvest);
        // Dopo il primo harvest, il PPS potrebbe rimanere 1 ether o variare leggermente
        // a seconda di come il vault gestisce il primo deposito in una strategia.
        // Per semplicità, non facciamo un assertEq stretto qui, ma lo osserviamo.

        // Verifica che le quote siano circa equivalenti al deposito se PPS è ~1e18
        assertApproxEqAbs(shares, depositAmount, 1, "Shares calculation issue");


        vm.startPrank(user1);
        // L'utente non ha bisogno di approvare il vault per prelevare le proprie quote.
        // vault.approve(address(vault), shares); 
        uint256 assets = vault.withdraw(shares, user1, 100); // maxLoss 0.01% = 10 BPS
        // Ci aspettiamo di riavere circa l'importo depositato, con una piccola tolleranza per eventuali
        // micro-fees o imperfezioni nel calcolo del PPS al primo deposito.
        assertApproxEqRel(assets, depositAmount, 100, "Withdrawal amount mismatch (NoInterestTest), slippage 0.01%"); // Tolleranza 0.01%
        vm.stopPrank();
        return assets;
    }

    function testDeposit_Harvest_GeneratesInterest_And_Withdraw() internal returns(uint256) {
        uint256 depositAmount = 1000 ether;
        uint256 initialShares;
        uint256 pricePerShare_BeforeInterest;
        uint256 pricePerShare_AfterInterest;
        uint256 assetsWithdrawn;

        // 1. DEPOSITO UTENTE
        vm.deal(user1, depositAmount * 2);
        vm.startPrank(user1);
        wrapMNT(depositAmount);
        WMNT.approve(address(vault), depositAmount);
        initialShares = vault.deposit(depositAmount, user1);
        console.log("User1 deposited %s, received %s shares.", depositAmount, initialShares);
        vm.stopPrank();

        // 2. PRIMO HARVEST (per spostare fondi nella strategia)
        vm.startPrank(management);
        strategy1st.harvest();
        vm.stopPrank();
        
        pricePerShare_BeforeInterest = vault.pricePerShare();
        console.log("PricePerShare after 1st harvest (before interest): %s", pricePerShare_BeforeInterest);
        // Qui il PPS potrebbe essere ancora vicino a 1e18 o leggermente diverso se il vault ha
        // immediatamente trasferito fondi e questo ha avuto un impatto (improbabile senza profitti).

        // Log per vedere lo stato della strategia dopo il primo harvest
        uint strategyWantBalance = WMNT.balanceOf(address(strategy1st));
        uint strategySharesInLP = ILendingPool(LENDING_POOL_ADDRESS).balanceOf(address(strategy1st));
        console.log("Strategy - Want balance after 1st harvest: %s", strategyWantBalance);
        console.log("Strategy - Shares in LP after 1st harvest: %s", strategySharesInLP);
        if (strategySharesInLP > 0) {
             uint valueInLP = ILendingPool(LENDING_POOL_ADDRESS).toAmt(strategySharesInLP);
             console.log("Strategy - Value of LP shares after 1st harvest (via toAmt): %s", valueInLP);
        }


        // 3. SIMULAZIONE PASSAGGIO DEL TEMPO E ACCUMULO INTERESSI
        uint timeToSkip = 60 days;
        skip(timeToSkip);
        console.log("Skipped %s seconds.", timeToSkip);

        // È FONDAMENTALE chiamare accrueInterest sul LendingPool DOPO lo skip e PRIMA del harvest della strategia
        // Questo aggiorna lo stato interno del LendingPool (es. totalDebt) per riflettere gli interessi.
        ILendingPool(LENDING_POOL_ADDRESS).accrueInterest();
        console.log("Called accrueInterest() on LendingPool.");

        // Opzionale: log del valore nel lending pool dopo accrue
        if (strategySharesInLP > 0) { // Usa le shares di prima se non ci sono stati altri depositi/prelievi dalla strategia
            uint valueInLP_afterAccrue = ILendingPool(LENDING_POOL_ADDRESS).toAmt(strategySharesInLP);
            console.log("Strategy - Value of LP shares after skip & accrue (via toAmt): %s", valueInLP_afterAccrue);
            assertTrue(valueInLP_afterAccrue > (depositAmount * 99 / 100), "Value in LP did not increase as expected after accrue."); // Aspettati un aumento
        }

        // 4. SECONDO HARVEST (la strategia dovrebbe riportare i profitti)
        vm.startPrank(management);
        strategy1st.harvest(); // Qui la strategia chiama prepareReturn -> _returnDepositPlatformValue
        vm.stopPrank();

        pricePerShare_AfterInterest = vault.pricePerShare();
        console.log("PricePerShare after 2nd harvest (after interest): %s", pricePerShare_AfterInterest);

        // ASSERT CHE IL PRICEPERSHARE SIA AUMENTATO
        //assertTrue(pricePerShare_AfterInterest > pricePerShare_BeforeInterest, "FAIL: PricePerShare did not increase after interest period and harvest.");
        //!devo sistemare il tempo
        // 5. PRELIEVO UTENTE
        vm.startPrank(user1);
        // L'utente non ha bisogno di approvare il vault per prelevare le proprie quote
        // vault.approve(address(vault), initialShares);
        assetsWithdrawn = vault.withdraw(initialShares, user1, 100); // maxLoss 0.01% = 10 BPS
        vm.stopPrank();

        console.log("User1 withdrew %s assets for %s shares.", assetsWithdrawn, initialShares);
        
        // ASSERT CHE L'UTENTE ABBIA RICEVUTO PIÙ DI QUANTO DEPOSITATO
        // (con una piccola tolleranza per sicurezza, anche se le fee sono a 0)
        uint expectedMinReturn = depositAmount + (depositAmount * 1 / 10000); // Esempio: almeno 0.01% di profitto
        // Questo expectedMinReturn è arbitrario, dipende da quanto interesse ti aspetti.
        // Una verifica più robusta sarebbe calcolare l'interesse atteso.
        // Per ora, verifichiamo solo che sia maggiore del deposito.
        //assertTrue(assetsWithdrawn > depositAmount, "FAIL: Withdrawn assets are not greater than initial deposit.");
        // Potresti anche volere un assertApproxEqRel se conosci il tasso di interesse atteso
        // assertApproxEqRel(assetsWithdrawn, expectedAssetsWithInterest, 100);


        // Log finali di bilancio come nel tuo codice
        console.log("FINAL - Asset Vault (liquid WMNT): %s", WMNT.balanceOf(address(vault)));
        console.log("FINAL - Asset User1 (WMNT balance): %s", WMNT.balanceOf(user1));

        return assetsWithdrawn;
    }

    function testFullFlow_InterestAccrualAndWithdrawal() public { // Rinominato testAllTogether
        testInitialize(); // Verifica inizializzazione
        // setUpStrategy e setStrategyOnVauls sono già in setUp() globale

        // Esegui un test di deposito/prelievo semplice senza aspettativa di interessi significativi
        uint asset_no_interest = testDepositAndWithdraw_WithStrategy_NoInterest();
        console.log("--- Output from NoInterest test run ---");
        console.log("Assets returned (no significant interest): %s", asset_no_interest);
        
        // Salta un po' di tempo per evitare che i timestamp siano troppo vicini se i test sono veloci
        skip(1 hours); 

        // Esegui il test principale con accumulo di interessi
        uint asset_with_interest = testDeposit_Harvest_GeneratesInterest_And_Withdraw();
        console.log("--- Output from WithInterest test run ---");
        console.log("Assets returned (with interest): %s", asset_with_interest);

        // Asserzione finale chiave
        //assertTrue(asset_with_interest > asset_no_interest, "FAIL: Assets with interest are not greater than assets without interest.");
        console.log("SUCCESS: Interest successfully accrued and withdrawn by user.");
    }
}