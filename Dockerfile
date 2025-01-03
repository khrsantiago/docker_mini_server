








# Agregar esto al archivo
# chmod g+s /shared
# chown -R :sharedgroup /shared
# chmod -R 775 /shared














# Usamos una imagen base con soporte para la GPU
FROM nvidia/cuda:12.4.0-base-ubuntu22.04

# Configurar el entorno para evitar interacciones
ENV DEBIAN_FRONTEND=noninteractive

# Instalar paquetes necesarios
RUN rm /etc/apt/sources.list.d/cuda* && \
    apt-get update && apt-get install -y \
    openssh-server sudo curl build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
    libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev \
    liblzma-dev git zsh fonts-powerline && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Instala paquetes extras
RUN apt-get update && apt-get install -y \
    nano \
    iproute2 \
    net-tools \
    curl \
    wget \
    traceroute \
    telnet \
    vim-tiny \
    iputils-ping \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Instalar NetBird
RUN curl -fsSL https://pkgs.netbird.io/install.sh | sh

# Crear el grupo para los desarrolladores
RUN groupadd sharedgroup

# Instalar pyenv para todos los usuarios
RUN git clone https://github.com/pyenv/pyenv.git /usr/local/pyenv && \
    echo 'export PYENV_ROOT="/usr/local/pyenv"' >> /etc/profile && \
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> /etc/profile && \
    echo 'eval "$(pyenv init --path)"' >> /etc/profile && \
    echo 'export PYENV_ROOT="/usr/local/pyenv"' >> /etc/bash.bashrc && \
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> /etc/bash.bashrc && \
    echo 'eval "$(pyenv init --path)"' >> /etc/bash.bashrc && \
    echo 'eval "$(pyenv init -)"' >> /etc/bash.bashrc && \
    # Configurar pyenv para root en su .bashrc
    echo 'export PYENV_ROOT="/usr/local/pyenv"' >> /root/.bashrc && \
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> /root/.bashrc && \
    echo 'eval "$(pyenv init --path)"' >> /root/.bashrc && \
    echo 'eval "$(pyenv init -)"' >> /root/.bashrc

# Instalar Python 3.11.10 mediante pyenv
RUN bash -c 'source /etc/profile && pyenv install 3.11.10 && pyenv global 3.11.10'

# Asegurar que los directorios de pyenv sean accesibles para todos los usuarios del grupo sharedgroup
RUN chmod -R 775 /usr/local/pyenv && \
    chown -R root:sharedgroup /usr/local/pyenv && \
    chmod -R 775 /usr/local/pyenv/shims && \
    chmod -R 775 /usr/local/pyenv/versions

# Instalar Zsh, Oh My Zsh y Powerlevel10k
RUN chsh -s /bin/zsh && \
    curl -Lo install.sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh && \
    sh install.sh --unattended && \
    rm install.sh && \
    # Instalar Powerlevel10k
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH/custom/themes/powerlevel10k && \
    # Instalar plugins de autosuggestions y zsh-syntax-highlighting
    git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH/custom/plugins/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting $ZSH/custom/plugins/zsh-syntax-highlighting

# Configurar zsh
RUN echo 'source $ZSH/oh-my-zsh.sh' >> /root/.zshrc && \
    echo 'source $ZSH/oh-my-zsh.sh' >> /home/$user/.zshrc && \
    echo 'source $ZSH/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh' >> /home/$user/.zshrc && \
    echo 'source $ZSH/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' >> /home/$user/.zshrc && \
    # Agregar pyenv a .zshrc
    echo 'export PYENV_ROOT="/usr/local/pyenv"' >> /root/.zshrc && \
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> /root/.zshrc && \
    echo 'eval "$(pyenv init --path)"' >> /root/.zshrc && \
    echo 'eval "$(pyenv init -)"' >> /root/.zshrc && \
    echo 'export PYENV_ROOT="/usr/local/pyenv"' >> /home/$user/.zshrc && \
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> /home/$user/.zshrc && \
    echo 'eval "$(pyenv init --path)"' >> /home/$user/.zshrc && \
    echo 'eval "$(pyenv init -)"' >> /home/$user/.zshrc

# Copiar el archivo de usuarios y el archivo de claves públicas al contenedor
COPY users.txt /tmp/users.txt
COPY authorized_keys.txt /tmp/authorized_keys.txt

# Crear los usuarios dinámicamente a partir del archivo users.txt
RUN while IFS= read -r user && IFS= read -r key <&3; do \
    useradd -m -s /bin/zsh -G sharedgroup "$user" && \
    mkdir -p "/home/$user/.ssh" && \
    echo "$key" > "/home/$user/.ssh/authorized_keys" && \
    chmod 700 "/home/$user/.ssh" && \
    chmod 600 "/home/$user/.ssh/authorized_keys" && \
    chown -R "$user:sharedgroup" "/home/$user" && \
    # Agregar pyenv a .bashrc
    echo 'export PYENV_ROOT="/usr/local/pyenv"' >> "/home/$user/.bashrc" && \
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> "/home/$user/.bashrc" && \
    echo 'eval "$(pyenv init --path)"' >> "/home/$user/.bashrc" && \
    # Agregar pyenv a .zshrc
    echo 'export PYENV_ROOT="/usr/local/pyenv"' >> "/home/$user/.zshrc" && \
    echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> "/home/$user/.zshrc" && \
    echo 'eval "$(pyenv init --path)"' >> "/home/$user/.zshrc" && \
    echo 'eval "$(pyenv init -)"' >> "/home/$user/.zshrc"; \
done < /tmp/users.txt 3< /tmp/authorized_keys.txt

# Crear una carpeta compartida accesible por todos los usuarios del grupo sharedgroup
RUN mkdir -p /shared && \
    chown root:sharedgroup /shared && \
    chmod 775 /shared

# Configurar el servidor SSH
RUN mkdir /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's|#AuthorizedKeysFile.*|AuthorizedKeysFile /home/%u/.ssh/authorized_keys|' /etc/ssh/sshd_config

# Configurar el directorio predeterminado para los usuarios
RUN echo "cd /shared" >> /etc/bash.bashrc && \
    echo "cd /shared" >> /etc/zsh/zshrc

# Exponer el puerto SSH
EXPOSE 22

# Agregar el soporte de NVIDIA
RUN apt-get update && apt-get install -y nvidia-utils-550 && \
    echo "export PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH" >> /etc/bash.bashrc

# Comando para iniciar el servidor SSH
CMD ["/usr/sbin/sshd", "-D"]
