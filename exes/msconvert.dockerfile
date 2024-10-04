FROM proteowizard/pwiz-skyline-i-agree-to-the-vendor-licenses

RUN mv /wineprefix64 /temporary_wine_dir && \
    chmod -R 777 /temporary_wine_dir && \
    mkdir /wineprefix64 && \
    chmod -R 777 /wineprefix64

