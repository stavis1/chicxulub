FROM proteowizard/pwiz-skyline-i-agree-to-the-vendor-licenses

COPY run_msconvert.sh /
RUN mv /wineprefix64 /temporary_wine_dir && \
    chmod -R 777 /temporary_wine_dir && \
    mkdir /wineprefix64 && \
    chmod -R 777 /wineprefix64

