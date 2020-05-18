package conf

import (
	"fmt"
	"oasisTracker/common/baseconf"
	"oasisTracker/common/baseconf/types"
)

type (
	Config struct {
		API                API
		LogLevel           string
		Mysql              types.MysqlParams
		Clickhouse         Clickhouse
		CORSAllowedOrigins []string
		Scanner            Scanner
	}
	API struct {
		ListenOnPort       uint64
		CORSAllowedOrigins []string
	}
	Scanner struct {
		NodeRPS    uint64
		Database   string
		NodeConfig string
	}
	Clickhouse struct {
		Protocol string
		Host     string
		Port     uint
		User     string
		Password string
		Database string
	}
)

const (
	Service = "oasis"
)

func NewFromFile(cfgFile *string) (cfg Config, err error) {
	err = baseconf.Init(&cfg, cfgFile)
	if err != nil {
		return cfg, err
	}

	err = cfg.Validate()
	if err != nil {
		return cfg, err
	}

	return cfg, nil
}

// Validate validates all Config fields.
func (config Config) Validate() error {
	if config.Clickhouse.Protocol == "" {
		return fmt.Errorf("bad clickhouse Protocol")
	}
	if config.Clickhouse.Port == 0 {
		return fmt.Errorf("bad clickhouse Port")
	}
	if config.Clickhouse.Host == "" {
		return fmt.Errorf("no clickhouse Host")
	}
	if config.Clickhouse.User == "" {
		return fmt.Errorf("no clickhouse User")
	}
	return baseconf.ValidateBaseConfigStructs(&config)
}
