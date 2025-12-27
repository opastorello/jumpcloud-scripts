# JumpCloud Scripts

Esta é uma coleção de scripts de automação para sistemas Linux, projetados para instalar, atualizar, reparar ou configurar aplicações e configurações comuns em ambientes gerenciados pelo JumpCloud. O foco principal é manter uma base de código padronizada, reutilizável e modular, evitando duplicação de lógica entre os scripts.

## Estrutura do Repositório

- **`scripts/linux/`**: Contém scripts prontos para uso em estações de trabalho ou servidores Linux. Cada script é autônomo, mas pode ser integrado em fluxos de automação maiores, como comandos remotos no JumpCloud ou pipelines de CI/CD.

## Pré-requisitos

- **Sistemas Operacionais Suportados**: Baseados em Debian ou Ubuntu (a maioria dos scripts utiliza o gerenciador de pacotes `apt`). Para outros sistemas (ex.: CentOS/RHEL), adaptações podem ser necessárias.
- **Dependências Básicas**: 
  - `bash` (interpretador de shell padrão).
  - `sudo` (para elevação de privilégios).
  - `curl` ou `wget` (para downloads via linha de comando).
- **Permissões**: Acesso de administrador (root) é requerido para operações que envolvam instalação de pacotes, modificações em configurações do sistema ou acesso a diretórios protegidos.
- **Outros**: Conexão à internet para baixar pacotes e dependências.

## Como Executar

1. **Baixe o Repositório** (se ainda não o tiver):
   ```bash
   git clone https://github.com/opastorello/jumpcloud-scripts.git
   cd jumpcloud-scripts
   ```

2. **Atribua Permissões de Execução** (para o script desejado):
   ```bash
   chmod +x scripts/linux/NOME_DO_SCRIPT.sh
   ```

3. **Execute o Script**:
   - Como usuário root ou via `sudo` (recomendado para scripts que alteram o sistema):
     ```bash
     sudo ./scripts/linux/NOME_DO_SCRIPT.sh [ARGUMENTOS_OPCIONAIS]
     ```
   - Exemplo: Para instalar o Docker Desktop:
     ```bash
     sudo ./scripts/linux/DockerDesktop.sh
     ```

4. **Personalização**:
   - Consulte os comentários no início de cada script para entender sua funcionalidade, parâmetros disponíveis e variáveis de ambiente que podem ser ajustadas (ex.: caminhos de instalação ou versões específicas).
   - Alguns scripts aceitam argumentos via linha de comando; verifique o cabeçalho do arquivo para detalhes.

## Contribuição

Contribuições são bem-vindas! Para sugerir melhorias ou adicionar novos scripts:

1. Faça um fork do repositório.
2. Crie uma branch para sua feature (`git checkout -b feature/novo-script`).
3. Commit suas mudanças (`git commit -m 'Adiciona script para X'`).
4. Envie um pull request.

Siga as convenções de código: scripts em Bash, com shebang `#!/bin/bash`, comentários em português e tratamento de erros.

## Licença

Este projeto está licenciado sob a [MIT License](LICENSE). Sinta-se à vontade para usar, modificar e distribuir, desde que mantenha os créditos originais.
