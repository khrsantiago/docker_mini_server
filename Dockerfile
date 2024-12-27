# Usamos una imagen base con soporte para la GPU
FROM nvidia/cuda:12.1.1-base-ubuntu20.04

# Instalar paquetes necesarios
RUN apt-get update && apt-get install -y \
    openssh-server sudo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Crear un usuario llamado dockeruser y darle permisos sudo
RUN useradd -m -s /bin/bash dockeruser && \
    echo "dockeruser:dockerpassword" | chpasswd && \
    usermod -aG sudo dockeruser && \
    echo "dockeruser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir /home/dockeruser/.ssh && \
    chown -R dockeruser:dockeruser /home/dockeruser/.ssh

# Configurar el servidor SSH
RUN mkdir /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Exponer el puerto SSH
EXPOSE 22

# Agregar el soporte de NVIDIA
RUN apt-get update && apt-get install -y nvidia-utils-525 && \
    echo "export PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH" >> /etc/bash.bashrc

# Comando para iniciar el servidor SSH
CMD ["/usr/sbin/sshd", "-D"]
