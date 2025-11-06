// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RecebivelNFT is ERC721, Ownable {
    uint256 private _nextTokenId;


    struct Recebivel {
        uint256 valor;
        uint256 dataVencimento;
        address emissor;
        address pagador;
        bool quitado;
        // Removi 'preco' da struct pois voce ja tem um mapping 'precos' para isso
    }

    mapping(uint256 => Recebivel) public recebiveis; // Corrigido typo: Receivel -> Recebivel
    mapping(uint256 => uint256) public precos;

    event RecebivelCriado(uint256 indexed tokenId, address emissor, uint256 valor);
    event RecebivelListado(uint256 indexed tokenId, uint256 preco);
    event RecebivelVendido(uint256 indexed tokenId, address comprador, uint256 preco);
    event RecebivelQuitado(uint256 indexed tokenId, address pagador, uint256 valor);

    // Corrigido construtor Ownable
    constructor() ERC721("RecebivelNFT", "RECNFT") Ownable(msg.sender) {}

    // Removido onlyOwner para permitir que usuarios criem notas
    // Adicionado 'memory' na string uri se voce for usar (mas nao estava usando no seu codigo original)
    function mintRecebivel(uint256 valor, uint256 dataVencimento, address pagador) public {
        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId); // Quem cria recebe o NFT inicialmente

        recebiveis[tokenId] = Recebivel({
            valor: valor,
            dataVencimento: dataVencimento,
            emissor: msg.sender,
            pagador: pagador,
            quitado: false
        });

        emit RecebivelCriado(tokenId, msg.sender, valor);
    }

    function listForSale(uint256 tokenId, uint256 preco) public {
        require(ownerOf(tokenId) == msg.sender, "Voce nao e o dono deste recebivel");
        require(!recebiveis[tokenId].quitado, "Recebivel ja quitado nao pode ser vendido");
        precos[tokenId] = preco;
        emit RecebivelListado(tokenId, preco);
    }

    function buy(uint256 tokenId) public payable {
        uint256 preco = precos[tokenId];
        require(preco > 0, "Este recebivel nao esta a venda");
        require(msg.value == preco, "Valor enviado incorreto");

        address owner = ownerOf(tokenId);
        require(owner != msg.sender, "Voce nao pode comprar seu proprio recebivel"); // Evita auto-compra

        // Efeito antes da interacao (padrao checks-effects-interactions)
        precos[tokenId] = 0;

        _transfer(owner, msg.sender, tokenId);
        payable(owner).transfer(msg.value);

        emit RecebivelVendido(tokenId, msg.sender, preco);
    }

    function pay(uint256 tokenId) public payable {
        Recebivel storage recebivel = recebiveis[tokenId];
        // Removi a restricao de so o pagador poder pagar. Flexibilidade para demo.
        // require(msg.sender == recebivel.pagador, "Voce nao e o pagador deste recebivel");
        require(msg.value >= recebivel.valor, "Valor insuficiente para quitar");
        require(!recebivel.quitado, "Este recebivel ja foi quitado");

        recebivel.quitado = true;
        
        address currentOwner = ownerOf(tokenId);
        payable(currentOwner).transfer(msg.value);

        emit RecebivelQuitado(tokenId, msg.sender, msg.value);
    }

    // MANTENHA ESTA FUNCAO APENAS PARA TESTES/DEMO COM POUCOS ITENS
    // ELA VAI QUEBRAR EM PRODUCAO COM MUITOS TOKENS
    function getRecebiveisOfOwner(address owner) public view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory result = new uint256[](balance);
        uint256 counter = 0;
        // Aviso: _nextTokenId pode ficar muito grande
        for (uint256 i = 0; i < _nextTokenId; i++) {
            // Verifica se o token ainda existe (caso voce implemente burn no futuro)
            try this.ownerOf(i) returns (address tokenOwner) {
                if (tokenOwner == owner) {
                    result[counter] = i;
                    counter++;
                }
            } catch {}
        }
        // Redimensiona o array caso tenha pulado tokens queimados (avancado)
        // Para o hackathon, o loop simples pode bastar se voce nao queimar tokens.
        return result;
    }
}